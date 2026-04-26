# frozen_string_literal: true

FactoryBot.define do
  factory :mod_action do
    action { "user_feedback_create" }
    values { { "user_id" => 1, "reason" => "test reason", "type" => "positive", "record_id" => 1 } }
  end
end
