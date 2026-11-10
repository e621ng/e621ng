# frozen_string_literal: true

FactoryBot.define do
  factory :forum_poll_option do
    association :poll, factory: :forum_poll
    sequence(:body) { |n| "Extra option #{n}" }
    position { 99 }
  end
end
