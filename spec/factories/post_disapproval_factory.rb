# frozen_string_literal: true

FactoryBot.define do
  factory :post_disapproval do
    association :post
    association :user
    reason  { "other" }
    message { nil }

    factory :borderline_quality_disapproval do
      reason { "borderline_quality" }
    end

    factory :not_relevant_disapproval do
      reason { "borderline_relevancy" }
    end

    factory :disapproval_with_message do
      message { "This post needs work." }
    end
  end
end
