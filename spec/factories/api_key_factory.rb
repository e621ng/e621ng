# frozen_string_literal: true

FactoryBot.define do
  factory :api_key do
    association :user
    sequence(:name) { |n| "api_key_#{n}" }
    # `key` is auto-generated via has_secure_token :key
    # expires_at defaults to nil (non-expiring key)

    # Key expiring in the future (passes validate_expiration_date)
    factory :expiring_api_key do
      expires_at { 3.days.from_now }
    end

    # Key already expired — set via update_columns after create to bypass validate_expiration_date
    factory :expired_api_key do
      after(:create) { |k| k.update_columns(expires_at: 1.day.ago) }
    end

    # Key expiring within 7 days with no prior notification (matches .expiring_soon scope)
    factory :expiring_soon_api_key do
      expires_at  { 5.days.from_now }
      notified_at { nil }
    end
  end
end
