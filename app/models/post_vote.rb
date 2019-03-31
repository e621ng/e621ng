class PostVote < ApplicationRecord
  class Error < Exception ; end

  belongs_to :post
  belongs_to :user
  attr_accessor :vote

  after_initialize :initialize_attributes, if: :new_record?
  validates_presence_of :post_id, :user_id, :score
  validates_inclusion_of :score, :in => [SuperVoter::MAGNITUDE, 1, 0, -1, -SuperVoter::MAGNITUDE]

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

    if vote == "up"
      self.score = magnitude
    elsif vote == "down"
      self.score = -magnitude
    elsif vote == "locked"
      self.score = 0
    end
  end

  def magnitude
    if user.is_super_voter?
      SuperVoter::MAGNITUDE
    else
      1
    end
  end
end
