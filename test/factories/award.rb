# frozen_string_literal: true

FactoryBot.define do
  factory(:award) do
    award_type
    user
    creator factory: :janitor_user
    reason { nil }
  end
end
