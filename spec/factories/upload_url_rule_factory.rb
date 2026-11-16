# frozen_string_literal: true

FactoryBot.define do
  factory :upload_url_rule do
    sequence(:label) { |n| "Sample URL #{n}" }
    pattern     { "example\\.com/sample/" }
    replacement { "example.com/full/" }
    message     { "" }
    handling    { "recommend" }
    enabled     { true }
    association :creator, factory: :user
    updater     { creator }

    factory :blocking_upload_url_rule do
      handling { "block" }
    end
  end
end
