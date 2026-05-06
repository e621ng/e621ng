# frozen_string_literal: true

FactoryBot.define do
  factory :artist_version do
    association :artist
    name          { generate(:artist_name) }
    other_names   { [] }
    urls          { [] }
    group_name    { "" }
    notes_changed { false }
    is_active     { true }
  end
end
