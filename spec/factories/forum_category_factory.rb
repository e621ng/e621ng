# frozen_string_literal: true

FactoryBot.define do
  factory :forum_category do
    sequence(:name) { |n| "Category #{n}" }
    description { "A forum category." }
    cat_order { 0 }
  end
end
