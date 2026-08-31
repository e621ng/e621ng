# frozen_string_literal: true

class TagUpdateRelatedJob < ApplicationJob
  sidekiq_options queue: "tags"

  def perform(tag_id)
    tag = Tag.find(tag_id)

    tag.update_related
  end
end
