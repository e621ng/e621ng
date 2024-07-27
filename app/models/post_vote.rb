# frozen_string_literal: true

class PostVote < UserVote
  validate :validate_user_can_vote

  def self.model_creator_column
    :uploader
  end

  def validate_user_can_vote
    if user.younger_than(3.days) && score == -1
      errors.add(:user, "must be 3 days old to downvote posts")
      return false
    end
    allowed = user.can_post_vote_with_reason
    if allowed != true
      errors.add(:user, User.throttle_reason(allowed))
      return false
    end
    true
  end
end
