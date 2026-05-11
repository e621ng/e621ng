# frozen_string_literal: true

FactoryBot.define do
  factory :user_name_change_request do
    association :user
    sequence(:desired_name) { |n| "new_name_#{n}" }
    original_name           { user.name }
    # Skip the 1-per-week rate limit by default so tests can create records freely.
    # Tests that specifically exercise the limit should pass skip_limited_validation: false.
    skip_limited_validation { true }
  end
end
