# frozen_string_literal: true

FactoryBot.define do
  factory :post_deletion do
    post { create(:post) }
    deleter { CurrentUser.user }
    creator_ip_addr { "127.0.0.1" }
    reason { "Test deletion reason" }
  end
end
