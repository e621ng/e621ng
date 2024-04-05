# frozen_string_literal: true

FactoryBot.define do
  factory(:user_name_change_request) do
    sequence(:desired_name) { |n| "desired_name_#{n}" }
    change_reason { "" }
  end
end
