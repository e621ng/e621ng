# frozen_string_literal: true

FactoryBot.define do
  factory(:post_report_reason) do
    reason { nil }
    creator { create(:user) }
    description { "test" }
  end
end
