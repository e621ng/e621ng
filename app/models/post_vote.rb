class PostVote < ApplicationRecord
  class Error < Exception ; end

  belongs_to :post
  belongs_to :user

  after_initialize :initialize_attributes, if: :new_record?
  validate :validate_user_can_vote
  validates :post_id, :user_id, :score, presence: true
  validates :score, inclusion: { :in => [1, 0, -1] }

  scope :for_user, ->(uid) {where("user_id = ?", uid)}

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
    self.user_ip_addr ||= CurrentUser.ip_addr
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

  module SearchMethods
    def search(params)
      q = super

      if params[:post_id].present?
        q = q.where('post_id = ?', params[:post_id])
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

      allow_complex_parameters = (params.keys & %w[post_id user_name user_id]).any?

      if allow_complex_parameters
        if params[:timeframe].present?
          q = q.where("updated_at >= ?", params[:timeframe].to_i.days.ago)
        end

        if params[:user_ip_addr].present?
          q = q.where("user_ip_addr <<= ?", params[:user_ip_addr])
        end

        if params[:score].present?
          q = q.where("score = ?", params[:score])
        end

        if params[:duplicates_only] == "1"
          subselect = PostVote.search(params.except("duplicates_only")).select(:user_ip_addr).group(:user_ip_addr).having("count(user_ip_addr) > 1").reorder("")
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
