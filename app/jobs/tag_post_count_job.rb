# frozen_string_literal: true

class TagPostCountJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    tag = Tag.find_by(id: args[0])
    return unless tag

    Tag.without_timeout do
      tag.fix_post_count
    end
  end
end
