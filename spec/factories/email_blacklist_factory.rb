# frozen_string_literal: true

FactoryBot.define do
  factory :email_blacklist do
    sequence(:domain) { |n| "spam#{n}.example.com" }
    reason { "Known spam domain." }
  end
end
