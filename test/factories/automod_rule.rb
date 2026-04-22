# frozen_string_literal: true

FactoryBot.define do
  factory(:automod_rule) do
    sequence(:name) { |n| "automod_rule_#{n}" }
    regex { "spam" }
    enabled { true }
    apply_to { 0 }
    creator

    trait(:for_comments)     { apply_to { 1 } }
    trait(:for_usernames)    { apply_to { 2 } }
    trait(:for_profile_text) { apply_to { 4 } }
    trait(:for_all)          { apply_to { 7 } }
  end
end
