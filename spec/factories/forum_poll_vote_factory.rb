# frozen_string_literal: true

FactoryBot.define do
  factory :forum_poll_vote do
    association :option, factory: :forum_poll_option
    poll { option.poll }
    association :user
    user_ip_addr { "127.0.0.1" }
  end
end
