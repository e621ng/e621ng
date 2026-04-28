# frozen_string_literal: true

FactoryBot.define do
  factory :comment_vote do
    user  { create(:user) }
    score { 1 }
    # `create(:comment)` sets creator_id from CurrentUser (whoever that is at factory
    # evaluation time). Use update_columns to replace the creator with a fresh user so
    # validate_comment_can_be_voted never sees comment.creator == CurrentUser.user.
    comment do
      c = create(:comment)
      c.update_columns(creator_id: create(:user).id)
      c
    end

    factory :down_comment_vote do
      score { -1 }
    end

    factory :locked_comment_vote do
      score { 0 }
    end
  end
end
