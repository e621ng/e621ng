# frozen_string_literal: true

FactoryBot.define do
  factory :destroyed_post do
    sequence(:post_id) { |n| n }
    md5 { Faker::Crypto.md5 }
    association :destroyer, factory: :user
    destroyer_ip_addr { "127.0.0.1" }
    post_data { {} }
    reason { "" }
    notify { true }

    factory :destroyed_post_with_uploader do
      association :uploader, factory: :user
      uploader_ip_addr { "127.0.0.2" }
    end
  end
end
