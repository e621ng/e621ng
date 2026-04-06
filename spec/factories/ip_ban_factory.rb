# frozen_string_literal: true

FactoryBot.define do
  sequence(:ip_ban_addr) { |n| "#{(n % 254) + 1}.2.3.4" }

  factory :ip_ban do
    # belongs_to_creator reads from CurrentUser if creator_id is nil;
    # forcing an explicit creator makes the factory self-contained.
    creator { create(:moderator_user) }
    ip_addr { generate(:ip_ban_addr) }
    reason  { "Test ban reason" }
  end
end
