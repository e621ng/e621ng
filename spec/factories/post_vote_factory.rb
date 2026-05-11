# frozen_string_literal: true

FactoryBot.define do
  factory :post_vote do
    user  { create(:user) }
    post  { create(:post) }
    score { 1 }

    # User must be 3+ days old to downvote; create an aged-up user to satisfy the check.
    factory :down_post_vote do
      score { -1 }
      user  { create(:user, created_at: 4.days.ago) }
    end

    factory :locked_post_vote do
      score { 0 }
    end
  end
end
