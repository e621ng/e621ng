# frozen_string_literal: true

FactoryBot.define do
  factory(:pool) do
    sequence(:name) { |n| "pool_#{n}" }
    association :creator, factory: :user
    sequence(:description) { |n| "pool_description_#{n}" }
  end
end
