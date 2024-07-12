# frozen_string_literal: true

class TagAliasJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    ta = TagAlias.find(args[0])
    ta.process!(update_topic: args[1])
  end
end
