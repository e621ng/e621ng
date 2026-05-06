# frozen_string_literal: true

FactoryBot.define do
  factory :avoid_posting do
    association :artist
    details     { "" }
    staff_notes { "" }
    is_active   { true }

    factory :inactive_avoid_posting do
      is_active { false }
    end
  end
end
