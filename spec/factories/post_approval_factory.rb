# frozen_string_literal: true

FactoryBot.define do
  factory :post_approval do
    # post.lock! in validate_approval requires the post to be persisted,
    # so we force creation even when the approval itself is only built.
    post { create(:pending_post) }
    association :user
  end
end
