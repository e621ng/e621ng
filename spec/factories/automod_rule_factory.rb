# frozen_string_literal: true

FactoryBot.define do
  factory :automod_rule do
    sequence(:name) { |n| "automod_rule_#{n}" }
    regex           { "spam" }
    enabled         { true }
    association :creator, factory: :user

    trait :for_comments do
      apply_to { AutomodRule.flag_value_for("comments") }
    end

    trait :for_usernames do
      apply_to { AutomodRule.flag_value_for("usernames") }
    end

    trait :for_profile_text do
      apply_to { AutomodRule.flag_value_for("profile_text") }
    end

    factory :disabled_automod_rule do
      enabled { false }
    end
  end
end
