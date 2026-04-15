# frozen_string_literal: true

FactoryBot.define do
  factory(:automod_rule) do
    sequence(:name) { |n| "automod_rule_#{n}" }
    regex { "spam" }
    enabled { true }
    creator
  end
end
