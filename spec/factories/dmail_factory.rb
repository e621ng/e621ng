# frozen_string_literal: true

FactoryBot.define do
  factory :dmail do
    sequence(:title) { |n| "Test DMail #{n}" }
    body             { "Hello, this is a test dmail body." }

    to   { create(:user) }
    from { create(:user) }

    after(:build) do |dmail|
      dmail.owner_id ||= dmail.to_id
    end

    bypass_limits         { true }
    no_email_notification { true }
  end
end
