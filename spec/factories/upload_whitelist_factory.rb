# frozen_string_literal: true

FactoryBot.define do
  factory :upload_whitelist do
    domain  { "example\\.com" }
    path    { "\\/.+" }
    note    { "Test whitelist entry" }
    reason  { "Allowed" }
    allowed { true }
    hidden  { false }

    factory :blocked_upload_whitelist do
      allowed { false }
      reason  { "Blocked" }
    end
  end
end
