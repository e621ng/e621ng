# frozen_string_literal: true

FactoryBot.define do
  factory(:ip_ban) do
    creator
    sequence(:reason) { |n| "ip_ban_reason_#{n}" }
  end
end
