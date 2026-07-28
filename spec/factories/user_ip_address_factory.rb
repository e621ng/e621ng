# frozen_string_literal: true

require "faker"

FactoryBot.define do
  factory :user_ip_address do
    user
    ip_addr { Faker::Internet.ip_v4_address }
    first_seen_at { Time.now - 1.day }
    last_seen_at { Time.now }
    hit_count { 1 }
    # subnet is a stored generated column; never set it.
  end
end
