# frozen_string_literal: true

FactoryBot.define do
  factory :post_version do
    association :post
    tags        { "tagme" }
    rating      { "s" }
    source      { "" }
    description { "" }
    locked_tags { "" }
    reason      { nil }
  end
end
