# frozen_string_literal: true

class ForumPostVote < ApplicationRecord
  belongs_to_creator
  belongs_to :forum_post
  validates :creator_id, uniqueness: { scope: :forum_post_id }
  validates :score, inclusion: { in: [-1, 0, 1] }
  validate :validate_creator_is_not_limited, on: :create
  scope :up, -> { where(score: 1) }
  scope :down, -> { where(score: -1) }
  scope :by, ->(user_id) { where(creator_id: user_id) }
  scope :excluding_user, ->(user_id) { where.not(creator_id: user_id) }
  after_save :update_vote_score

  def method_attributes
    super + [:creator_name]
  end

  def validate_creator_is_not_limited
    allowed = creator.can_forum_vote_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def up?
    score == 1
  end

  def down?
    score == -1
  end

  def meh?
    score == 0
  end

  def icon
    ForumPostVote.score_to_icon(score)
  end

  def vote_type
    ForumPostVote.score_to_str(score)
  end

  def self.score_to_icon(score)
    case score
    when 1
      :thumbs_up
    when -1
      :thumbs_down
    when 0
      :face_meh
    else
      :flame
    end
  end

  def self.score_to_str(score)
    case score
    when 1
      "up"
    when -1
      "down"
    when 0
      "meh"
    else
      "unknown"
    end
  end

  private

  def update_vote_score
    forum_post.update_vote_score
  end
end
