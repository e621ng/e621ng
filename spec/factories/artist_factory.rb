# frozen_string_literal: true

FactoryBot.define do
  sequence(:artist_name) { |n| "artist_#{n}" }

  factory :artist do
    name        { generate(:artist_name) }
    group_name  { "" }
    other_names { [] }
    is_active   { true }
    is_locked   { false }

    factory :locked_artist do
      is_locked { true }
    end

    factory :inactive_artist do
      is_active { false }
    end

    factory :artist_with_group do
      transient do
        group { nil }
      end
      group_name { group&.name || generate(:artist_name) }
    end
  end
end
