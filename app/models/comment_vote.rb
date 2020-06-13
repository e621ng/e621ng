class CommentVote < ApplicationRecord
  class Error < Exception;
  end

  belongs_to :comment
  belongs_to :user
  before_validation :initialize_user, :on => :create
  validates :user_id, :comment_id, :score, presence: true
  # validates :user_id, uniqueness: { :scope => :comment_id, :message => "have already voted for this comment" }
  validate :validate_user_can_vote
  validate :validate_comment_can_be_down_voted
  validates :score, inclusion: { :in => [-1, 0, 1], :message => "must be 1 or -1" }

  scope :for_user, ->(uid) {where("user_id = ?", uid)}


  def self.for_comments_and_user(comment_ids, user_id)
    return {} unless user_id
    CommentVote.where(comment_id: comment_ids, user_id: user_id).index_by(&:comment_id)
  end

  def validate_user_can_vote
    allowed = user.can_comment_vote_with_reason
    if allowed != true
      errors.add(:user, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def validate_comment_can_be_down_voted
    if is_positive? && comment.creator == CurrentUser.user
      errors.add :base, "You cannot upvote your own comments"
      false
    else
      true
    end
  end

  def is_positive?
    score == 1
  end

  def is_negative?
    score == -1
  end

  def is_locked?
    score == 0
  end

  def initialize_user
    self.user_id ||= CurrentUser.user.id
    self.user_ip_addr ||= CurrentUser.ip_addr
  end

  module SearchMethods
    def search(params)
      q = super

      if params[:comment_id].present?
        q = q.where("comment_id = ?", params[:comment_id].to_i)
      end

      if params[:user_name].present?
        user_id = User.name_to_id(params[:user_name])
        q = q.where('user_id = ?', user_id) if user_id
      end

      if params[:user_id].present?
        q = q.where('user_id = ?', params[:user_id].to_i)
      end

      q = q.order(id: :desc)

      q
    end
  end

  extend SearchMethods
end
