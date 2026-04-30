# frozen_string_literal: true

FactoryBot.define do
  factory(:user_feedback) do
    user
    category { "positive" }
    sequence(:body) { |n| "user_feedback_body_#{n}" }
  end
end
