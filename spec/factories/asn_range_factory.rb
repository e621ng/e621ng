# frozen_string_literal: true

FactoryBot.define do
  factory :asn_range do
    sequence(:first_ip) { |n| "198.51.#{n % 256}.0" }
    sequence(:last_ip) { |n| "198.51.#{n % 256}.255" }
    sequence(:asn) { |n| 64_512 + n }
    sequence(:name) { |n| "EXAMPLE-AS-#{n}" }
    country { "US" }
  end
end
