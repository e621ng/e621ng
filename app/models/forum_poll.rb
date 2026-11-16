# frozen_string_literal: true

class ForumPoll < ApplicationRecord
  class BallotError < StandardError; end

  DEFAULT_DURATION = "7d"
  EMBED_REGEX = /\bthumb #\d+/i

  belongs_to :topic, class_name: "ForumTopic", foreign_key: :forum_topic_id, inverse_of: :poll
  belongs_to :creator, class_name: "User"
  belongs_to :closed_early_by, class_name: "User", optional: true
  # Votes before options: dependent callbacks run in declaration order and votes reference options.
  has_many :votes, class_name: "ForumPollVote", dependent: :delete_all
  has_many :options, -> { order(:position) }, class_name: "ForumPollOption", dependent: :destroy, inverse_of: :poll

  accepts_nested_attributes_for :options, allow_destroy: true

  # Duration preset key submitted by the form; expires_at is derived from it on create.
  attr_accessor :duration

  before_validation :set_creator, on: :create
  before_validation :apply_duration, on: :create
  before_validation :assign_positions

  validates :expires_at, presence: true, on: :update
  validates :max_choices, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :validate_duration, on: :create
  validate :validate_options
  validate :validate_creator_can_create, on: :create
  validate :validate_creator_is_not_limited, on: :create

  def self.durations
    Danbooru.config.forum_poll_durations
  end

  def live_options
    options.reject(&:marked_for_destruction?)
  end

  def open?
    expires_at.present? && expires_at > Time.current
  end

  def closed?
    !open?
  end

  def closed_early?
    closed_early_by_id.present?
  end

  def multiple?
    max_choices > 1
  end

  # Options that embed posts get the card/grid layout so thumbnails fit.
  def has_embeds?
    options.any? { |option| option.body.to_s.match?(EMBED_REGEX) }
  end

  def selected_option_ids(user)
    return [] if user.blank? || !user.is_member?
    votes.where(user_id: user.id).pluck(:forum_poll_option_id)
  end

  ### Permissions ###

  def can_edit?(user = CurrentUser.user)
    return false if user.blank? || !user.is_member?
    user.id == creator_id && voter_count == 0 && open?
  end

  def can_close?(user = CurrentUser.user)
    return false if user.blank? || !user.is_member?
    return false unless open?
    user.is_moderator? || user.id == creator_id
  end

  def can_destroy?(user = CurrentUser.user)
    user.present? && user.is_admin?
  end

  def vote_denial_reason(user = CurrentUser.user)
    return "Log in to vote" if user.blank? || !user.is_member?
    return "This poll has closed" unless open?
    allowed = user.can_forum_poll_vote_with_reason
    return "You #{User.throttle_reason(allowed)}" unless allowed == true
    nil
  end

  def can_vote?(user = CurrentUser.user)
    vote_denial_reason(user).nil?
  end

  ### Actions ###

  def close!(by:)
    with_lock do
      raise BallotError, "This poll has already closed" unless open?
      update!(expires_at: Time.current, closed_early_by: by)
    end
    ModAction.log(:forum_poll_close, { forum_topic_id: forum_topic_id, user_id: creator_id }) if by.id != creator_id
  end

  # Replaces the user's whole ballot. Serialized per poll by the row lock, which keeps the
  # counters exact; the unique index on votes is only a backstop.
  def cast_ballot!(user, option_ids, ip_addr: nil)
    ids = Array(option_ids).compact_blank.map(&:to_i).uniq

    with_lock do
      raise BallotError, "This poll has closed" unless open?
      raise BallotError, "Invalid option" unless (ids - options.map(&:id)).empty?
      raise BallotError, "You can select at most #{max_choices} #{'option'.pluralize(max_choices)}" if ids.size > max_choices

      if ids.any?
        allowed = user.can_forum_poll_vote_with_reason
        raise BallotError, "You #{User.throttle_reason(allowed)}" unless allowed == true
      end

      existing = votes.where(user_id: user.id).pluck(:forum_poll_option_id)
      added = ids - existing
      removed = existing - ids

      votes.where(user_id: user.id, forum_poll_option_id: removed).delete_all if removed.any?
      if added.any?
        now = Time.current
        ForumPollVote.insert_all(added.map do |option_id|
          { forum_poll_id: id, forum_poll_option_id: option_id, user_id: user.id, user_ip_addr: ip_addr, created_at: now }
        end)
      end

      ForumPollOption.where(id: added).update_all("vote_count = vote_count + 1") if added.any?
      ForumPollOption.where(id: removed).update_all("vote_count = vote_count - 1") if removed.any?

      if existing.empty? && ids.any?
        ForumPoll.where(id: id).update_all("voter_count = voter_count + 1")
      elsif existing.any? && ids.empty?
        ForumPoll.where(id: id).update_all("voter_count = voter_count - 1")
      end
    end

    reload
  rescue ActiveRecord::RecordNotUnique
    raise BallotError, "Your vote could not be saved, please try again"
  end

  private

  def set_creator
    self.creator_id ||= CurrentUser.id
  end

  def apply_duration
    length = self.class.durations[duration.to_s]
    self.expires_at = Time.current + length if length
  end

  def assign_positions
    live_options.each_with_index { |option, index| option.position = index }
  end

  def validate_duration
    return if self.class.durations.key?(duration.to_s)
    errors.add(:base, "Duration is not one of the allowed presets")
  end

  def validate_options
    live = live_options
    max = Danbooru.config.forum_poll_max_options
    errors.add(:base, "Poll needs at least one option") if live.empty?
    errors.add(:base, "Poll cannot have more than #{max} options") if live.size > max
    errors.add(:base, "Max choices cannot exceed the number of options") if max_choices.to_i > live.size && live.any?

    normalized = live.map { |option| option.body.to_s.squish.downcase }
    errors.add(:base, "Poll options must be unique") if normalized.uniq.size != normalized.size
  end

  def validate_creator_can_create
    return if creator.blank? || creator.can_create_forum_poll?
    errors.add(:base, "You are not allowed to create polls")
  end

  def validate_creator_is_not_limited
    return if creator.blank?
    allowed = creator.can_forum_poll_with_reason
    return if allowed == true
    errors.add(:base, "You #{User.throttle_reason(allowed, 'daily')}")
  end
end
