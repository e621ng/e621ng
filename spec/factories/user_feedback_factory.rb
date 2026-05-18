# frozen_string_literal: true

FactoryBot.define do
  factory :user_feedback do
    association :user
    # Creator must be persisted for is_moderator? to return true (level predicates require id.present?)
    creator { create(:moderator_user) }
    body     { "Test feedback body" }
    category { "positive" }

    factory :neutral_user_feedback do
      category { "neutral"  }
    end

    factory :negative_user_feedback do
      category { "negative" }
    end

    factory :deleted_user_feedback do
      is_deleted { true }
    end
  end
end
