# frozen_string_literal: true

class CommentVote < UserVote
  validate :validate_user_can_vote
  validate :validate_comment_can_be_voted

  def self.for_comments_and_user(comment_ids, user_id)
    return {} unless user_id
    CommentVote.where(comment_id: comment_ids, user_id: user_id).index_by(&:comment_id)
  end

  def self.model_creator_column
    :creator
  end

  def validate_user_can_vote
    allowed = user.can_comment_vote_with_reason
    if allowed != true
      errors.add(:user, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def validate_comment_can_be_voted
    if (is_positive? || is_negative?) && comment.creator == CurrentUser.user
      errors.add :base, "You cannot vote on your own comments"
    end
    if comment.is_sticky
      errors.add :base, "You cannot vote on sticky comments"
    end
  end
end
