# frozen_string_literal: true

FactoryBot.define do
  factory :favorite_folder do
    user
    sequence(:name) { |n| "folder_#{n}" }
    parent { nil }
  end
end
