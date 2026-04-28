# frozen_string_literal: true

FactoryBot.define do
  sequence(:pool_name) { |n| "pool_name_#{n}" }

  factory :pool do
    name        { generate(:pool_name) }
    description { "A pool description." }
    category    { "series" }
    is_active   { true }
    post_ids    { [] }

    factory :series_pool do
      category { "series" }
    end

    factory :collection_pool do
      category { "collection" }
    end
  end
end
