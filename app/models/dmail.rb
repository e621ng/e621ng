# frozen_string_literal: true

class Dmail < ApplicationRecord
  normalizes :body, with: ->(body) { body.gsub("\r\n", "\n") }
  validates :title, :body, presence: { on: :create }
  validates :title, length: { minimum: 1, maximum: 250 }
  validates :body, length: { minimum: 1, maximum: Danbooru.config.dmail_max_size }
  validate :recipient_accepts_dmails, on: :create
  validate :user_not_limited, on: :create

  belongs_to :owner, class_name: "User"
  belongs_to :to, class_name: "User"
  belongs_to :from, class_name: "User"

  after_initialize :initialize_attributes, if: :new_record?
  before_create :auto_read_if_filtered
  after_create :update_recipient_unread_count
  after_commit :send_email, on: :create, unless: :no_email_notification

  attr_accessor :bypass_limits, :no_email_notification

  module AddressMethods
    def to_name=(name)
      self.to_id = User.name_to_id(name)
    end

    def initialize_attributes
      self.from_id ||= CurrentUser.id
      self.creator_ip_addr ||= CurrentUser.ip_addr
    end
  end

  module FactoryMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def create_split(params)
        copy = nil

        Dmail.transaction do
          # recipient's copy
          copy = Dmail.new(params)
          copy.owner_id = copy.to_id
          copy.save unless copy.to_id == copy.from_id
          raise ActiveRecord::Rollback if copy.errors.any?

          # sender's copy
          copy = Dmail.new(params)
          copy.bypass_limits = true
          copy.owner_id = copy.from_id
          copy.is_read = true
          copy.save
        end

        copy
      end

      def create_automated(params)
        CurrentUser.as_system do
          dmail = Dmail.new(from: User.system, **params)
          dmail.owner = dmail.to
          dmail.save
          dmail
        end
      end
    end

    def build_response(options = {})
      Dmail.new do |dmail|
        if title =~ /Re:/
          dmail.title = title
        else
          dmail.title = "Re: #{title}"
        end
        dmail.owner_id = from_id
        dmail.body = quoted_body
        dmail.to_id = from_id unless options[:forward]
        dmail.from_id = to_id
      end
    end
  end

  module SearchMethods
    def sent_by_id(user_id)
      where("dmails.from_id = ? AND dmails.owner_id != ?", user_id, user_id)
    end

    def sent_by(user)
      where("dmails.from_id = ? AND dmails.owner_id != ?", user.id, user.id)
    end

    def active
      where("is_deleted = ?", false)
    end

    def deleted
      where("is_deleted = ?", true)
    end

    def read
      where(is_read: true)
    end

    def unread
      where("is_read = false AND is_deleted = false")
    end

    def visible
      where("owner_id = ?", CurrentUser.id)
    end

    def search(params)
      q = super

      q = q.attribute_matches(:title, params[:title_matches])
      q = q.attribute_matches(:body, params[:message_matches])

      q = q.where_user(:to_id, :to, params)
      q = q.where_user(:from_id, :from, params)

      q = q.attribute_matches(:is_read, params[:is_read])
      q = q.attribute_matches(:is_deleted, params[:is_deleted])

      q = q.read if params[:read].to_s.truthy?
      q = q.unread if params[:read].to_s.falsy?

      q.order(id: :desc)
    end
  end

  module ApiMethods
    def to_name
      to&.pretty_name
    end

    def from_name
      from&.pretty_name
    end

    def method_attributes
      super + %i[to_name from_name]
    end
  end

  include AddressMethods
  include FactoryMethods
  include ApiMethods
  extend SearchMethods

  def user_not_limited
    # System user must be able to send dmails at a very high rate, do not rate limit the system user.
    return true if bypass_limits == true
    return true if from_id == User.system.id
    return true if from.is_janitor?

    allowed = CurrentUser.can_dmail_with_reason
    if allowed != true
      errors.add(:base, "Sender #{User.throttle_reason(allowed)}")
      return
    end
    minute_allowed = CurrentUser.can_dmail_minute_with_reason
    if minute_allowed != true
      errors.add(:base, "Please wait a bit before trying to send again")
      return
    end
    day_allowed = CurrentUser.can_dmail_day_with_reason
    if day_allowed != true
      errors.add(:base, "Sender #{User.throttle_reason(day_allowed, 'daily')}")
    end
  end

  def recipient_accepts_dmails
    unless to
      errors.add(:to_name, "not found")
      return false
    end
    return true if from_id == User.system.id
    return true if from.is_janitor?
    if to.disable_user_dmails
      errors.add(:to_name, "has disabled DMails")
      return false
    end
    if from.disable_user_dmails && !to.is_janitor?
      errors.add(:to_name, "is not a valid recipient while blocking DMails from others. You may only message janitors and above")
      return false
    end
    if to.is_blacklisting_user?(from)
      errors.add(:to_name, "does not wish to receive DMails from you")
      false
    end
  end

  def quoted_body
    "[section=#{from.pretty_name} said:]\n#{body}\n[/section]\n\n"
  end

  def send_email
    if to.receive_email_notifications? && to.email =~ /@/ && owner_id == to.id
      UserMailer.dmail_notice(self).deliver_now
    end
  end

  def mark_as_read!
    return if is_read?
    Dmail.transaction do
      update_column(:is_read, true)
      count = owner.unread_dmail_count
      if count <= 0
        owner.recalculate_unread_dmail_count!
      else
        owner.update_columns(unread_dmail_count: count - 1)
      end
    end
  end

  def mark_as_unread!
    Dmail.transaction do
      update_column(:is_read, false)
      owner.update_columns(unread_dmail_count: owner.unread_dmail_count + 1)
    end
  end

  def is_automated?
    from == User.system
  end

  def filtered?
    CurrentUser.dmail_filter.try(:filtered?, self)
  end

  def auto_read_if_filtered
    if owner_id != CurrentUser.id && to.dmail_filter.try(:filtered?, self)
      self.is_read = true
    end
  end

  def update_recipient_unread_count
    return if owner_id == CurrentUser.user.id || is_deleted? || is_read?
    to.update_columns(unread_dmail_count: to.unread_dmail_count + 1)
  end

  def visible_to?(user, key = nil)
    owner_id == user.id ||
      (user.is_staff? && (
          is_accessible_by_key?(key) ||
          (user.is_moderator? && is_accessible_to_moderators?) ||
          (user.is_admin? && is_accessible_to_admins?)
        ))
  end

  USE_VERSIONING = false
  CURRENT_VERSION = 1
  VERSION_REGEX = /^v([0-9]+)::([\S]+)$/

  if USE_VERSIONING
    def generate_key(version = CURRENT_VERSION, key: nil)
      if key && (m = Dmail::VERSION_REGEX.match(key))
        version = m.match(1)
      end
      send(:"generate_key_v#{version}")
    rescue StandardError; "INVALID_VERSION"
    end

    def generate_keys
      [generate_key_v1, generate_key_v2]
    end
  else
    def generate_key(...)
      send(:"generate_key_v#{CURRENT_VERSION}")
    end
  end

  private

  # Includes the id of the DMail, so only works on that copy; if deleted, can't be used on the other party's copy. As there's no way to get their copy's id, currently doesn't matter.
  def generate_key_v1
    "v1::#{Digest::SHA256.hexdigest("#{id}::#{from.id}::#{to.id}::#{body}")}"
  end

  # Removes the id of the DMail, so if deleted, can still be used on the other party's copy. As there's no way to get their copy's id, currently doesn't matter. This isn't unique, so `created_at` is added.
  # IDEA: use utc?
  def generate_key_v2
    "v2::#{Digest::SHA256.hexdigest("#{created_at.to_i}::#{from.id}::#{to.id}::#{body}")}"
  end

  def is_accessible_by_key?(key)
    key.present? && (to.is_staff? || from.is_staff?) && key_matches?(key)
  end

  if USE_VERSIONING
    def key_matches?(key)
      (v = VERSION_REGEX.match(key)&.match(1)) && (key == generate_key(v))
    end
  else
    def key_matches?(key)
      key == generate_key
    end
  end

  def is_accessible_to_moderators?
    from_id == User.system.id || Ticket.where(qtype: "dmail", disp_id: id).exists?
  end

  def is_accessible_to_admins?
    to.is_admin? || from.is_admin?
  end
end
