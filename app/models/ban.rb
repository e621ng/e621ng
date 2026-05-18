# frozen_string_literal: true

class Ban < ApplicationRecord
  attr_accessor :is_permaban

  before_validation :initialize_banner_id, on: :create
  before_validation :initialize_permaban, on: %i[update create]

  after_create :create_feedback
  after_create :update_user_on_create
  after_create :create_ban_mod_action
  after_create :push_pubsub_ban
  after_update :create_ban_update_mod_action
  after_update :push_pubsub_update
  after_destroy :update_user_on_destroy
  after_destroy :create_unban_mod_action
  after_destroy :push_pubsub_unban

  belongs_to :user
  belongs_to :banner, class_name: "User"

  validate :validate_user_is_inferior
  validates :reason, :duration, presence: true

  scope :unexpired, -> { where("bans.expires_at > ? OR bans.expires_at IS NULL", Time.now) }
  scope :expired, -> { where.not(bans: { expires_at: nil }).where("bans.expires_at <= ?", Time.now) }

  def self.is_banned?(user)
    where(["user_id = ? AND (expires_at > ? OR expires_at IS NULL)", user.id, Time.now]).exists?
  end

  def self.search(params)
    q = super

    q = q.where_user(:banner_id, :banner, params)
    q = q.where_user(:user_id, :user, params)

    q = q.attribute_matches(:reason, params[:reason_matches])

    q = q.expired if params[:expired].to_s.truthy?
    q = q.unexpired if params[:expired].to_s.falsy?

    case params[:order]
    when "expires_at_desc"
      q = q.order("bans.expires_at desc")
    else
      q = q.apply_basic_order(params)
    end

    q
  end

  def self.prune!
    expired.includes(:user).find_each do |ban|
      ban.user.unban! if ban.user.ban_expired?
    end
  end

  def update_user_on_create
    user.level = User::Levels::BLOCKED
    # Don't validate in order for deleted users to be bannable
    user.save(validate: false)
  end

  def update_user_on_destroy
    user.level = User::Levels::MEMBER
    user.save(validate: false)
  end

  def user_name
    user&.name
  end

  def user_name=(username)
    self.user_id = User.name_to_id(username)
  end

  def create_feedback
    user.feedback.create(
      category: "negative",
      body: "Banned #{expires_at.nil? ? 'permanently' : "for #{humanized_duration}"}.\n#{reason}",
    )
  end

  module DurationMethods
    def duration=(dur)
      dur = dur.to_i
      if dur < 0
        self.expires_at = nil
      else
        self.expires_at = dur.days.from_now
      end
      @duration = dur if dur != 0
    end

    def duration
      @duration
    end

    def humanized_duration
      return "permanent" if expires_at.nil?
      ApplicationController.helpers.distance_of_time_in_words(created_at, expires_at)
    end

    def humanized_expiration
      return "never" if expires_at.nil?
      ApplicationController.helpers.compact_time expires_at
    end

    def expire_days
      return "never" if expires_at.nil?
      ApplicationController.helpers.time_ago_in_words(expires_at)
    end

    def expired?
      return false if expires_at.nil?
      expires_at < Time.now
    end

    def expire!
      self.expires_at = Time.now
      save
    end
  end

  module InitializationMethods
    def initialize_banner_id
      self.banner_id = CurrentUser.id if banner_id.blank?
    end

    def initialize_permaban
      self.duration = -1 if is_permaban == "1"
    end
  end

  module ModActionMethods
    def create_ban_mod_action
      ModAction.log(:user_ban, { duration: duration, reason: reason, user_id: user_id })
    end

    def create_ban_update_mod_action
      ModAction.log(:user_ban_update, { user_id: user_id, ban_id: id, expires_at: expires_at, expires_at_was: expires_at_before_last_save, reason: reason, reason_was: reason_before_last_save })
    end

    def create_unban_mod_action
      ModAction.log(:user_unban, { user_id: user_id })
    end
  end

  module PubSubMethods
    def push_pubsub(action)
      Cache.redis.publish("ban_updates", pubsub_hash(action).to_json)
    end

    def push_pubsub_ban
      push_pubsub("create")
    end

    def push_pubsub_update
      push_pubsub("update")
    end

    def push_pubsub_unban
      push_pubsub("delete")
    end

    def pubsub_hash(action)
      {
        action: action,
        ban: {
          id: id,
          user_id: user_id,
          banner_id: banner.id,
          expires_at: expires_at,
          reason: reason,
        },
      }
    end
  end

  module ValidationMethods
    def validate_user_is_inferior
      return false if user.nil? || banner.nil?

      if user.is_admin?
        errors.add(:base, "You can never ban an admin.")
        return false
      end

      if user.is_moderator? && !banner.is_admin?
        errors.add(:base, "Only admins can ban moderators.")
        return false
      end

      if banner.is_moderator?
        return true
      end

      errors.add(:base, "Permission denied.")
      false
    end
  end

  include DurationMethods
  include InitializationMethods
  include ModActionMethods
  include PubSubMethods
  include ValidationMethods
end
