# frozen_string_literal: true

FactoryBot.define do
  factory(:artist) do
    sequence(:name) { |n| "artist_#{n}" }
    is_active { true }
    association :creator, factory: :user
  end
end
