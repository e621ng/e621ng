# frozen_string_literal: true

FactoryBot.define do
  factory(:ban) do |f|
    banner factory: :admin_user
    sequence(:reason) { |n| "ban_reason_#{n}" }
    duration { 60 }
  end
end
