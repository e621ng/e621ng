# frozen_string_literal: true

class TagNukeJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args
  self.enqueue_after_transaction_commit = true

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    tag_name = args[0]
    tag = Tag.find_by_normalized_name(tag_name)
    updater_id = args[1]
    updater_ip_addr = args[2]
    return if tag.nil?

    finalize_tag_id = tag.id
    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      create_undo_information(tag)
      migrate_posts(tag.name)
      ModAction.log(:nuke_tag, { tag_name: tag_name })
    end
  ensure
    # In `ensure` so a job that dies or exhausts its retries still reindexes what it changed.
    TagNukeFinalizeJob.perform_later(finalize_tag_id) if finalize_tag_id
  end

  def migrate_posts(tag_name)
    Thread.current[:skip_post_index_update] = true
    Post.sql_raw_tag_match(tag_name).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.remove_tag(tag_name)
        post.save!
      end
    end
  ensure
    Thread.current[:skip_post_index_update] = false
  end

  def create_undo_information(tag)
    post_ids = Post.without_timeout { Post.sql_raw_tag_match(tag.name).pluck(:id) }
    recorded = TagRelUndo.where(tag_rel: tag).unapplied.flat_map(&:post_ids)
    # A retry re-runs this with a shrinking set; a later nuke of the same tag brings new posts.
    return if (post_ids - recorded).empty?

    TagRelUndo.create!(tag_rel: tag, undo_data: post_ids)
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
