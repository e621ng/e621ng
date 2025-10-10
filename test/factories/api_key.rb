# frozen_string_literal: true

FactoryBot.define do
  factory(:api_key) do
    sequence(:name) { |n| "api_key_#{n}" }
    association(:user)
  end
end
