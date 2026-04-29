# frozen_string_literal: true

FactoryBot.define do
  factory(:comment) do
    post { create(:post) }
    sequence(:body) { |n| "comment_body_#{n}" }
    creator_ip_addr { "127.0.0.1" }
  end
end
