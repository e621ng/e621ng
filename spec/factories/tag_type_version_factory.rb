# frozen_string_literal: true

FactoryBot.define do
  factory :tag_type_version do
    association :tag
    association :creator, factory: :user
    old_type  { 0 }
    new_type  { 1 }
    is_locked { false }
  end
end
