# frozen_string_literal: true

class UpdateApiKeyUsageJob < ApplicationJob
  queue_as :low_prio

  sidekiq_options(
    lock: :until_executed,
    on_conflict: :reject,
    lock_args_method: :lock_args,
  )

  def self.lock_args(args)
    [args[0]] # ignore different ip and user agent
  end

  def perform(api_key_id, ip_address, user_agent = nil)
    api_key = ApiKey.find_by(id: api_key_id)
    return unless api_key

    api_key.update_usage!(ip_address, user_agent)
  end
end
