# frozen_string_literal: true

class TagPostCountJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    tag = Tag.find(args[0])

    tag.fix_post_count
  end
end
