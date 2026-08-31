# frozen_string_literal: true

class TagPostCountJob < ApplicationJob
  # until_executing: a recount requested while one is running must not be
  # dropped; the lock only dedupes queued duplicates.
  sidekiq_options queue: "tags", lock: :until_executing, lock_args_method: :lock_args, lock_ttl: 1.hour.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(tag_id)
    tag = Tag.find_by(id: tag_id)
    return unless tag

    Tag.without_timeout do
      tag.fix_post_count
    end
  end
end
