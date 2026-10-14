# frozen_string_literal: true

class UpdateTagCategoryJob < ApplicationJob
  # until_executing: a category change while one update runs must not be
  # dropped; the lock only dedupes queued duplicates.
  sidekiq_options queue: "low_prio", lock: :until_executing, lock_args_method: :lock_args, lock_ttl: 1.hour.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    @tag = Tag.find(id)
    @tag.update_category_post_counts!
  end
end
