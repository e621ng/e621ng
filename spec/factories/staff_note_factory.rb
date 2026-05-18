# frozen_string_literal: true

FactoryBot.define do
  factory :staff_note do
    association :user, factory: :user
    body { "A staff note body." }
  end
end
