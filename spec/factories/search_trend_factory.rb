# frozen_string_literal: true

FactoryBot.define do
  factory :search_trend do
    sequence(:tag) { |n| "trend_tag_#{n}" }
    day { Time.now.utc.to_date }
    count { 1 }
  end
end
