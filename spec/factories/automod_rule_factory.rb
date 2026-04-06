# frozen_string_literal: true

FactoryBot.define do
  factory :automod_rule do
    sequence(:name) { |n| "automod_rule_#{n}" }
    regex           { "spam" }
    enabled         { true }

    factory :disabled_automod_rule do
      enabled { false }
    end
  end
end
