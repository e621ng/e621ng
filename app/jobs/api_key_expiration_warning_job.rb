# frozen_string_literal: true

class ApiKeyExpirationWarningJob < ApplicationJob
  queue_as :low_prio

  def perform
    ApiKey.expiring_soon.find_each do |api_key|
      Maintenance::User::ApiKeyExpirationMailer.expiration_notice(api_key.user, api_key).deliver_now
      api_key.update_column(:notified_at, Time.current)
    end
  end
end
