# frozen_string_literal: true

FactoryBot.define do
  factory :search_trend_blacklist do
    sequence(:tag) { |n| "blacklist_tag_#{n}" }
    reason         { "test reason" }
  end
end
