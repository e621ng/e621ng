# frozen_string_literal: true

FactoryBot.define do
  factory :forum_subscription do
    association :user
    association :forum_topic
    last_read_at { 1.hour.ago }
  end
end
