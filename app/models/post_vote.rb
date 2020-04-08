class PostVote < ApplicationRecord
  class Error < Exception ; end

  belongs_to :post
  belongs_to :user

  after_initialize :initialize_attributes, if: :new_record?
  validate :validate_user_can_vote
  validates :post_id, :user_id, :score, presence: true
  validates :score, inclusion: { :in => [1, 0, -1] }

  scope :for_user, ->(uid) {where("user_id = ?", uid)}

  def self.positive_user_ids
    select_values_sql("select user_id from post_votes where score > 0 group by user_id having count(*) > 100")
  end

  def self.negative_post_ids(user_id)
    select_values_sql("select post_id from post_votes where score < 0 and user_id = ?", user_id)
  end

  def self.positive_post_ids(user_id)
    select_values_sql("select post_id from post_votes where score > 0 and user_id = ?", user_id)
  end

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
