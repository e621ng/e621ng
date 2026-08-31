# frozen_string_literal: true

FactoryBot.define do
  sequence(:saved_search_name) { |n| "saved_search_#{n}" }

  factory :saved_search do
    query { "tag_#{SecureRandom.hex(6)}" }
    name  { generate(:saved_search_name) }
    is_tracked { false }
    association :user
  end
end
