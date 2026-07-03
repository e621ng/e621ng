# frozen_string_literal: true

FactoryBot.define do
  sequence(:artist_url_url) { |n| "https://www.example.com/artist_#{n}/" }

  factory :artist_url do
    association :artist
    url       { generate(:artist_url_url) }
    is_active { true }

    factory :inactive_artist_url do
      is_active { false }
    end
  end
end
