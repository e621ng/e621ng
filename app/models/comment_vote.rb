class CommentVote < ApplicationRecord
  class Error < Exception;
  end

  belongs_to :comment
  belongs_to :user
  before_validation :initialize_user, :on => :create
  validates :user_id, :comment_id, :score, presence: true
  # validates :user_id, uniqueness: { :scope => :comment_id, :message => "have already voted for this comment" }
  validate :validate_user_can_vote
  validate :validate_comment_can_be_voted
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

  def validate_comment_can_be_voted
    if (is_positive? || is_negative?) && comment.creator == CurrentUser.user
      errors.add :base, "You cannot vote on your own comments"
    end
    if comment.is_sticky
      errors.add :base, "You cannot vote on sticky comments"
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
        if user_id
          q = q.where('user_id = ?', user_id)
        else
          q = q.none
        end
      end

      if params[:user_id].present?
        q = q.where('user_id = ?', params[:user_id].to_i)
      end

      allow_complex_parameters = (params.keys & %w[comment_id user_name user_id]).any?

      if allow_complex_parameters
        if params[:timeframe].present?
          q = q.where("comment_votes.updated_at >= ?", params[:timeframe].to_i.days.ago)
        end

        if params[:user_ip_addr].present?
          q = q.where("user_ip_addr <<= ?", params[:user_ip_addr])
        end

        if params[:score].present?
          q = q.where("comment_votes.score = ?", params[:score])
        end

        if params[:comment_creator_name].present?
          comment_creator_id = User.name_to_id(params[:comment_creator_name])
          if comment_creator_id
            q = q.joins(:comment).where("comments.creator_id = ?", comment_creator_id)
          else
            q = q.none
          end
        end

        if params[:duplicates_only] == "1"
          subselect = CommentVote.search(params.except("duplicates_only")).select(:user_ip_addr).group(:user_ip_addr).having("count(user_ip_addr) > 1").reorder("")
          q = q.where(user_ip_addr: subselect)
        end
      end

      if params[:order] == "ip_addr" && allow_complex_parameters
        q = q.order(:user_ip_addr)
      else
        q = q.apply_default_order(params)
      end
      q
    end
  end

  extend SearchMethods
end
