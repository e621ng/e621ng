# frozen_string_literal: true

FactoryBot.define do
  factory :forum_post_vote do
    association :forum_post
    score { 1 }

    factory :down_forum_post_vote do
      score { -1 }
    end

    factory :meh_forum_post_vote do
      score { 0 }
    end
  end
end
