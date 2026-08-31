# frozen_string_literal: true

class TagNukeJob < ApplicationJob
  include TransactionalEnqueue
  sidekiq_options queue: "tags", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  # This many failed posts means something systemic, not scattered bad data.
  FAILURE_LIMIT = 100

  def self.lock_args(args)
    [args[0]]
  end

  def perform(tag_name, updater_id, updater_ip_addr)
    tag = Tag.find_by_normalized_name(tag_name)
    return if tag.nil?

    finalize_tag_id = tag.id
    stragglers = []
    failures = []
    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      snapshot = create_undo_information(tag)
      migrate_posts(tag.name, snapshot, stragglers, failures)
      # Stragglers are in no snapshot row; give them one so they can be restored.
      TagRelUndo.create!(tag_rel: tag, undo_data: stragglers) if stragglers.any?
      # Raised after the other steps so they complete, but before the ModAction
      # so retries (which reattempt only the failed posts) don't duplicate it.
      raise_failure_summary(failures) if failures.any?
      ModAction.log(:nuke_tag, { tag_name: tag_name })
    end
  ensure
    # A job that dies or exhausts its retries still reindexes what it changed, including stragglers.
    TagNukeFinalizeJob.perform_async(finalize_tag_id, stragglers) if finalize_tag_id
  end

  def migrate_posts(tag_name, snapshot = nil, stragglers = [], failures = [])
    Thread.current[:skip_post_index_update] = true
    Post.sql_raw_tag_match(tag_name).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.remove_tag(tag_name)
        post.save!
      end
      # Posts that gained the tag after the undo snapshot.
      stragglers << post.id if snapshot&.exclude?(post.id)
    rescue ActiveRecord::RecordInvalid => e
      # Skip so one invalid post can't wedge every post after it across retries.
      failures << "##{post.id} (#{e.record.errors.full_messages.join(', ')})"
      raise_failure_summary(failures) if failures.size >= FAILURE_LIMIT
    end
    stragglers
  ensure
    Thread.current[:skip_post_index_update] = false
  end

  def raise_failure_summary(failures)
    shown = failures.first(10).join("; ")
    shown += "; and #{failures.size - 10} more" if failures.size > 10
    raise JobError, "skipped #{failures.size} invalid posts: #{shown}"
  end

  # Returns every id the undo rows now cover, so migration can spot unsnapshotted posts.
  def create_undo_information(tag)
    post_ids = Post.without_timeout { Post.sql_raw_tag_match(tag.name).pluck(:id) }
    recorded = TagRelUndo.where(tag_rel: tag).unapplied.flat_map(&:post_ids)
    # A retry re-runs this with a shrinking set; a later nuke of the same tag brings new posts.
    TagRelUndo.create!(tag_rel: tag, undo_data: post_ids) if (post_ids - recorded).any?
    (post_ids + recorded).to_set
  end

  def self.process_undo!(tag)
    TagRelUndo.where(tag_rel: tag, applied: false).find_each do |tag_rel_undo|
      Post.where(id: tag_rel_undo.undo_data).find_each do |post|
        post.do_not_version_changes = true
        post.add_tag(tag.name)
        post.save
      end
      tag_rel_undo.update(applied: true)
    end
  end
end
