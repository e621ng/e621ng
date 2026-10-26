# frozen_string_literal: true

FactoryBot.define do
  factory :tag_subscription do
    association :user
    association :tag
  end
end
