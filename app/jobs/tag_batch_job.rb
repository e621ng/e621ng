# frozen_string_literal: true

class TagBatchJob < ApplicationJob
  include TransactionalEnqueue
  sidekiq_options queue: "tags"

  # This many failed posts means something systemic, not scattered bad data.
  FAILURE_LIMIT = 100

  def perform(antecedent, consequent, updater_id, updater_ip_addr)
    resolved = nil
    stragglers = []
    failures = []

    from, *from_remaining = TagQuery.scan(antecedent.downcase)
    to, *to_remaining = TagQuery.scan(consequent.downcase)
    raise JobError, "#{antecedent} or #{consequent} has unexpected format" if from_remaining.any? || to_remaining.any?

    updater = User.find(updater_id)

    CurrentUser.scoped(updater, updater_ip_addr) do
      resolved = TagAlias.to_aliased([to]).first
      migrate_posts(from, to, resolved, stragglers, failures)
      migrate_blacklists(from, to)
      # Raised after the other steps so they complete, but before the ModAction
      # so retries (which reattempt only the failed posts) don't duplicate it.
      raise_failure_summary(failures) if failures.any?
      ModAction.log(:mass_update, { antecedent: antecedent, consequent: consequent })
    end
  ensure
    # In `ensure` so a job that dies or exhausts its retries still reindexes what it changed.
    TagBatchFinalizeJob.perform_async(resolved, stragglers) if resolved
  end

  def migrate_posts(from, to, resolved = TagAlias.to_aliased([to]).first, stragglers = [], failures = [])
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

  def migrate_blacklists(from, to)
    User.without_timeout do
      User.where_ilike(:blacklisted_tags, "*#{from}*").find_each(batch_size: 50) do |user|
        fixed_blacklist = TagAlias.to_aliased_query(user.blacklisted_tags, overrides: { from => to }, comments: true)
        user.update_column(:blacklisted_tags, fixed_blacklist)
      end
    end
  end
end
