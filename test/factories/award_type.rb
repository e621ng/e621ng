# frozen_string_literal: true

FactoryBot.define do
  factory(:award_type) do
    sequence(:name) { |n| "award_type_#{n}" }
    description { "An award" }
    creator factory: :admin_user
  end
end
