# frozen_string_literal: true

class TagBatchJob < ApplicationJob
  queue_as :tags
  self.enqueue_after_transaction_commit = true

  def perform(*args)
    antecedent = args[0]
    consequent = args[1]
    updater_id = args[2]
    updater_ip_addr = args[3]

    resolved = nil
    stragglers = []

    from, *from_remaining = TagQuery.scan(antecedent.downcase)
    to, *to_remaining = TagQuery.scan(consequent.downcase)
    raise JobError, "#{antecedent} or #{consequent} has unexpected format" if from_remaining.any? || to_remaining.any?

    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      resolved = TagAlias.to_aliased([to]).first
      migrate_posts(from, to, resolved, stragglers)
      migrate_blacklists(from, to)
      ModAction.log(:mass_update, { antecedent: antecedent, consequent: consequent })
    end
  ensure
    # In `ensure` so a job that dies or exhausts its retries still reindexes what it changed.
    TagBatchFinalizeJob.perform_later(resolved, stragglers) if resolved
  end

  def migrate_posts(from, to, resolved = TagAlias.to_aliased([to]).first, stragglers = [])
    Thread.current[:skip_post_index_update] = true
    Post.sql_raw_tag_match(from).find_each do |post|
      post.with_lock do
        post.do_not_version_changes = true
        post.remove_tag(from)
        post.add_tag(to)
        post.save!
      end
      # normalize_tags can alias, lock or invalidate the consequent away.
      stragglers << post.id if post.tag_array.exclude?(resolved)
    end
    stragglers
  ensure
    Thread.current[:skip_post_index_update] = false
  end

  def migrate_blacklists(from, to)
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{from}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, overrides: { from => to }, comments: true)
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end
end
