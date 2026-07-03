# frozen_string_literal: true

FactoryBot.define do
  factory :search_trend_hourly do
    sequence(:tag) { |n| "trend_tag_#{n}" }
    hour { Time.now.utc.beginning_of_hour }
    count { 1 }
    processed { false }
  end
end
