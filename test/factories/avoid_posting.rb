# frozen_string_literal: true

FactoryBot.define do
  factory(:avoid_posting) do
    association :artist
    association :creator, factory: :bd_staff_user
    creator_ip_addr { "127.0.0.1" }
  end
end
