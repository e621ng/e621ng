# frozen_string_literal: true

FactoryBot.define do
  factory(:post_set) do
    creator
    creator_ip_addr { "127.0.0.1" }
    sequence(:name) { |n| "post_set_name_#{n}" }
    sequence(:shortname) { |n| "post_set_shortname_#{n}" }
  end
end
