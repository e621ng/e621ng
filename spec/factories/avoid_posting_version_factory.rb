# frozen_string_literal: true

FactoryBot.define do
  factory :avoid_posting_version do
    association :avoid_posting
    details     { "" }
    staff_notes { "" }
    is_active   { true }
  end
end
