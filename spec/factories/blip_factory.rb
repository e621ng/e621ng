# frozen_string_literal: true

FactoryBot.define do
  factory :blip do
    body { "A short blip body." }

    factory :deleted_blip do
      is_deleted { true }
    end
  end
end
