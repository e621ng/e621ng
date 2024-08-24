# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag_reason) do
    sequence(:name) { |n| "reason_#{n}" }
    reason { "reason" }
    text { "text" }
    parent { false }
  end
end
