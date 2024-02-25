# frozen_string_literal: true

class ForumPostVote < ApplicationRecord
  belongs_to_creator
  belongs_to :forum_post
  validates :creator_id, uniqueness: {scope: :forum_post_id}
  validates :score, inclusion: {in: [-1, 0, 1]}
  validate :validate_creator_is_not_limited, on: :create
  scope :up, -> {where(score: 1)}
  scope :down, -> {where(score: -1)}
  scope :by, ->(user_id) {where(creator_id: user_id)}
  scope :excluding_user, ->(user_id) {where("creator_id <> ?", user_id)}

  def creator_name
    if association(:creator).loaded?
      return creator&.name || "Anonymous"
    end
    User.id_to_name(creator_id)
  end

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

  def fa_class
    if score == 1
      "fa-thumbs-up"
    elsif score == -1
      "fa-thumbs-down"
    else
      "fa-face-meh"
    end
  end

  def vote_type
    if score == 1
      return "up"
    elsif score == -1
      return "down"
    elsif score == 0
      return "meh"
    else
      raise
    end
  end
end
