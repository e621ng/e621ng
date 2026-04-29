# frozen_string_literal: true

FactoryBot.define do
  factory :post_report_reason do
    sequence(:reason) { |n| "Reason #{n}" }
    description { "This is a description of the reason." }
  end
end
