# frozen_string_literal: true

class TagAliasJob < ApplicationJob
  sidekiq_options queue: "tags", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(alias_id, update_topic)
    ta = TagAlias.find(alias_id)
    ta.process!(update_topic: update_topic)
  end
end
