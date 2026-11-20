# frozen_string_literal: true

class TagUpdateRelatedJob < ApplicationJob
  sidekiq_options queue: "tags", lock: :until_executed, lock_ttl: 1.hour.to_i, retry: 3

  def perform(tag_id)
    # The tag may have been deleted while the job was queued.
    Tag.find_by(id: tag_id)&.update_related
  end
end
