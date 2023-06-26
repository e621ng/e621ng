class Dmail < ApplicationRecord
  validates :title, :body, presence: { on: :create }
  validates :title, length: { minimum: 1, maximum: 250 }
  validates :body, length: { minimum: 1, maximum: Danbooru.config.dmail_max_size }
  validate :sender_is_not_banned, on: :create
  validate :recipient_accepts_dmails, on: :create
  validate :user_not_limited, on: :create

  belongs_to :owner, :class_name => "User"
  belongs_to :to, :class_name => "User"
  belongs_to :from, :class_name => "User"

  after_initialize :initialize_attributes, if: :new_record?
  before_create :auto_read_if_filtered
  after_create :update_recipient
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

  module ApiMethods
    def method_attributes
      super + [:key]
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
      where("is_read = false and is_deleted = false")
    end

    def visible
      where("owner_id = ?", CurrentUser.id)
    end

    def to_name_matches(name)
      where("to_id = (select _.id from users _ where lower(_.name) = ?)", name.downcase)
    end

    def from_name_matches(name)
      where("from_id = (select _.id from users _ where lower(_.name) = ?)", name.downcase)
    end

    def search(params)
      q = super

      q = q.attribute_matches(:title, params[:title_matches])
      q = q.attribute_matches(:body, params[:message_matches])

      if params[:to_name].present?
        q = q.to_name_matches(params[:to_name])
      end

      if params[:to_id].present?
        q = q.where("to_id = ?", params[:to_id].to_i)
      end

      if params[:from_name].present?
        q = q.from_name_matches(params[:from_name])
      end

      if params[:from_id].present?
        q = q.where("from_id = ?", params[:from_id].to_i)
      end

      q = q.attribute_matches(:is_read, params[:is_read])
      q = q.attribute_matches(:is_deleted, params[:is_deleted])

      q = q.read if params[:read].to_s.truthy?
      q = q.unread if params[:read].to_s.falsy?

      q.order(created_at: :desc)
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
    return true if from.is_moderator?
    allowed = CurrentUser.can_dmail_with_reason
    minute_allowed = CurrentUser.can_dmail_minute_with_reason
    if allowed != true || minute_allowed != true
      errors.add(:base, "Sender #{User.throttle_reason(allowed != true ? allowed : minute_allowed)}")
      false
    end
    true
  end

  def sender_is_not_banned
    if from.try(:is_banned?)
      errors.add(:base, "Sender is banned and cannot send messages")
      return false
    else
      return true
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
      return false
    end
  end

  def quoted_body
    "[quote]\n#{from.pretty_name} said:\n\n#{body}\n[/quote]\n\n"
  end

  def send_email
    if to.receive_email_notifications? && to.email =~ /@/ && owner_id == to.id
      UserMailer.dmail_notice(self).deliver_now
    end
  end

  def mark_as_read!
    return if Danbooru.config.readonly_mode?

    update_column(:is_read, true)
    owner.dmails.unread.count.tap do |unread_count|
      owner.update(has_mail: (unread_count > 0), unread_dmail_count: unread_count)
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

  def update_recipient
    if owner_id != CurrentUser.user.id && !is_deleted? && !is_read?
      to.update(has_mail: true, unread_dmail_count: to.dmails.unread.count)
    end
  end

  def visible_to?(user)
    return true if user.is_moderator? && (from_id == User.system.id || Ticket.exists?(qtype: "dmail", disp_id: id))
    return true if user.is_admin? && (to.is_admin? || from.is_admin?)
    owner_id == user.id
  end
end
