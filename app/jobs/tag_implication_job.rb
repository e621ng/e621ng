# frozen_string_literal: true

class TagImplicationJob < ApplicationJob
  sidekiq_options queue: "tags", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(implication_id, update_topic)
    ti = TagImplication.find(implication_id)
    ti.process!(update_topic: update_topic)
  end
end
