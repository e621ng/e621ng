# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    # Post must be persisted — validate_post_exists uses Post.exists?(post_id)
    post { create(:post) }
    body { "A comment body." }

    factory :hidden_comment do
      is_hidden        { true }
    end

    factory :sticky_comment do
      is_sticky        { true }
    end

    factory :do_not_bump_comment do
      do_not_bump_post { true }
    end
  end
end
