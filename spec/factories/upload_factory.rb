# frozen_string_literal: true

FactoryBot.define do
  factory :upload do
    association      :uploader, factory: :user
    rating           { "s" }
    status           { "pending" }
    source           { "" }
    tag_string       { "" }
    uploader_ip_addr { "127.0.0.1" }
  end
end
