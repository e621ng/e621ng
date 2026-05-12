# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to_creator
  user_status_counter :ticket_count
  belongs_to :claimant, class_name: "User", optional: true
  belongs_to :handler, class_name: "User", optional: true
  belongs_to :accused, class_name: "User", optional: true
  belongs_to :post_report_reason, foreign_key: "report_reason", optional: true
  after_initialize :validate_type
  after_initialize :classify
  before_validation :initialize_fields, on: :create
  normalizes :reason, with: ->(reason) { reason.gsub("\r\n", "\n") }
  validates :qtype, presence: true
  validates :reason, presence: true
  validates :reason, length: { minimum: 2, maximum: Danbooru.config.ticket_max_size }
  validates :response, length: { minimum: 2 }, on: :update
  enum :status, %i[pending partial approved].index_with(&:to_s)
  after_create :push_pubsub_create
  after_update :push_pubsub_update_notification
  after_update :log_update
  after_update :create_dmail
  validate :validate_content_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create

  scope :for_creator, ->(uid) { where("creator_id = ?", uid) }

  attr_accessor :record_type, :send_update_dmail

  # Permissions Table
  # Creator can always view their own ticket. Admin always has unconditional view access.
  # For content-gated types, staff can view even if the content no longer exists.
  #
  # |    Type    |      Can Create     |  Min. View Level  | View Content Check |
  # |:----------:|:-------------------:|:-----------------:|:------------------:|
  # |    Blip    |      Accessible     |     Janitor+      |     Accessible     |
  # |   Comment  |      Accessible     |     Janitor+      |     Accessible     |
  # |    Dmail   | Visible & Recipient |    Moderator+     |      Visible       |
  # | Forum Post |       Visible       |     Janitor+      |      Visible       |
  # |    Pool    |         Any         |     Janitor+      |        -           |
  # |    Post    |         Any         |     Janitor+      |        -           |
  # |  Post Set  |       Visible       |     Janitor+      |      Visible       |
  # |    User    |         Any         |    Moderator+     |        -           |
  # |  Wiki Page |         Any         |     Janitor+      |        -           |
  # |    Other   |         None        |    Moderator+     |        -           |
  # |Replacement |       Visible       |     Janitor+      |      Visible       |

  module TicketTypes
    module Blip
      def can_create_for?(user)
        content&.can_access?(user)
      end

      def can_view?(user)
        return true if user.is_staff? && (content.blank? || content&.can_access?(user))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end
    end

    module Comment
      def can_create_for?(user)
        content&.is_accessible?(user, bypass_user_settings: true)
      end

      def can_view?(user)
        return true if user.is_staff? && (content.blank? || content&.is_accessible?(user, bypass_user_settings: true))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end
    end

    module Dmail
      def can_create_for?(user)
        content&.visible_to?(user) && content.to_id == user.id
      end

      def can_view?(user)
        return true if user.is_moderator? && (content.blank? || content&.visible_to?(user))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end

      def bot_target_name
        content&.from&.name
      end
    end

    module Forum
      # FIXME: Remove this by renaming the qtype value to the correct one
      def model
        ::ForumPost
      end

      def can_create_for?(user)
        content&.can_access?(user)
      end

      def can_view?(user)
        return true if user.is_staff? && (content.blank? || content&.can_access?(user))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end
    end

    module Pool
      def can_create_for?(_user)
        true
      end

      def can_view?(user)
        return true if user.is_staff?
        return true if user.id == creator_id
        false
      end

      def bot_target_name
        content&.name
      end
    end

    module Post
      def self.extended(modul)
        modul.class_eval do
          validates :report_reason, presence: true
        end
      end

      def subject
        reason.strip.split("\n").filter(&:present?)[0] || "Unknown Report Type"
      end

      def can_create_for?(_user)
        true
      end

      def can_view?(user)
        return true if user.is_staff?
        return true if user.id == creator_id
        false
      end

      def bot_target_name
        content&.uploader&.name
      end
    end

    module Set
      def model
        ::PostSet
      end

      def can_create_for?(user)
        content&.can_view?(user)
      end

      def can_view?(user)
        return true if user.is_staff? && (content.blank? || content&.can_view?(user))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end
    end

    module User
      def can_create_for?(_user)
        true
      end

      def can_view?(user)
        return true if user.is_moderator?
        return true if user.id == creator_id
        false
      end

      def bot_target_name
        content&.name
      end
    end

    module Wiki
      def model
        ::WikiPage
      end

      def can_create_for?(_user)
        true
      end

      def bot_target_name
        content&.title
      end

      def can_view?(user)
        return true if user.is_staff?
        return true if user.id == creator_id
        false
      end
    end

    module Replacement
      def model
        ::PostReplacement
      end

      def can_create_for?(user)
        content&.visible_to?(user)
      end

      def can_view?(user)
        return true if user.is_staff? && (content.blank? || content&.visible_to?(user))
        return true if user.is_admin?
        return true if user.id == creator_id
        false
      end

      def subject
        reason.strip.split("\n").filter(&:present?)[0] || "Unknown Report Type"
      end
    end
  end

  module APIMethods
    def hidden_attributes
      hidden = []

      unless can_view?(CurrentUser.user)
        hidden += %i[creator_id accused_id reason response report_reason]
        return super + hidden
      end

      hidden += %i[claimant_id] unless CurrentUser.is_staff?
      super + hidden
    end
  end

  module ValidationMethods
    def validate_type
      valid_types = TicketTypes.constants.map { |v| v.to_s.downcase }
      errors.add(:qtype, "is not valid") if valid_types.exclude?(qtype)
    end

    def validate_creator_is_not_limited
      return if creator == User.system

      # Hourly limit
      hourly_allowed = creator.can_ticket_hourly_with_reason
      if hourly_allowed != true
        errors.add(:creator, User.throttle_reason(hourly_allowed, "hourly"))
        return false
      end

      # Daily limit
      daily_allowed = creator.can_ticket_daily_with_reason
      if daily_allowed != true
        errors.add(:creator, User.throttle_reason(daily_allowed, "daily"))
        return false
      end

      # Active limit
      active_allowed = creator.can_ticket_active_with_reason
      if active_allowed != true
        errors.add(:creator, User.throttle_reason(active_allowed, "active"))
        return false
      end

      true
    end

    def validate_content_exists
      return if qtype.blank?
      errors.add model.name.underscore.to_sym, "does not exist" if content.nil?
    end

    def initialize_fields
      self.status = "pending"
      case qtype
      when "blip"
        self.accused_id = Blip.find(disp_id).creator_id
      when "forum"
        self.accused_id = ForumPost.find(disp_id).creator_id
      when "comment"
        self.accused_id = Comment.find(disp_id).creator_id
      when "dmail"
        self.accused_id = Dmail.find(disp_id).from_id
      when "user"
        self.accused_id = disp_id
      end
    end
  end

  module SearchMethods
    def for_accused(user_id)
      where(accused_id: user_id)
    end

    def active
      where(status: %w[pending partial])
    end

    def visible(user)
      if user.is_moderator?
        all
      elsif user.is_janitor?
        for_creator(user.id).or(where.not(qtype: %w[dmail user]))
      else
        for_creator(user.id)
      end
    end

    def search(params)
      q = super.includes(:creator).includes(:claimant)

      q = q.where_user(:creator_id, :creator, params)
      q = q.where_user(:claimant_id, :claimant, params)
      q = q.where_user(:accused_id, :accused, params)

      q = q.attribute_matches(:disp_id, params[:disp_id])

      if params[:qtype].present?
        q = q.where("qtype = ?", params[:qtype])
      end

      if params[:reason].present?
        q = q.attribute_matches(:reason, params[:reason])
      end

      if params[:status].present?
        case params[:status]
        when "pending_claimed"
          q = q.where("status = ? and claimant_id is not null", "pending")
        when "pending_unclaimed"
          q = q.where("status = ? and claimant_id is null", "pending")
        else
          q = q.where("status = ?", params[:status])
        end
      end

      if params[:order].present?
        q.apply_basic_order(params)
      else
        q.order(Arel.sql("CASE status WHEN 'pending' THEN 0 WHEN 'partial' THEN 1 ELSE 2 END ASC, id DESC"))
      end
    end
  end

  module ClassifyMethods
    def classify
      extend(TicketTypes.const_get(qtype.camelize)) if TicketTypes.constants.map(&:to_s).include?(qtype&.camelize)
    end
  end

  def content=(new_content)
    @content = new_content
    self.disp_id = new_content&.id
  end

  def content
    @content ||= model.find_by(id: disp_id)
  end

  def bot_target_name
    content&.creator&.name
  end

  def can_view?(user = CurrentUser.user)
    # Should not happen - individual ticket types override this method.
    return true if user.is_moderator?
    return true if user.id == creator_id
    false
  end

  def can_handle?(user = CurrentUser.user)
    user.is_moderator?
  end

  def can_claim?(user = CurrentUser.user)
    user.is_moderator?
  end

  def can_create_for?(_user)
    false
  end

  def model
    qtype.classify.constantize
  end

  def type_title
    model.name.titlecase
  end

  def subject
    trimmed = reason.strip
    if trimmed.length > 40
      "#{trimmed[0, 38]}..."
    else
      trimmed
    end
  end

  def open_duplicates
    Ticket.where(
      qtype: qtype,
      disp_id: disp_id,
      status: "pending",
    ).where.not(id: id)
  end

  def warnable?
    content.respond_to?(:user_warned!) && !content.was_warned? && pending?
  end

  module ClaimMethods
    def claim!(user = CurrentUser)
      transaction do
        ModAction.log(:ticket_claim, { ticket_id: id })
        update_attribute(:claimant_id, user.id)
        push_pubsub("claim")
      end
    end

    def unclaim!(_user = CurrentUser)
      transaction do
        ModAction.log(:ticket_unclaim, { ticket_id: id })
        update_attribute(:claimant_id, nil)
        push_pubsub("unclaim")
      end
    end
  end

  module NotificationMethods
    def create_dmail
      return if creator == User.system
      should_send = saved_change_to_status? || (send_update_dmail.to_s.truthy? && saved_change_to_response?)
      return unless should_send

      msg = <<~MSG.chomp
        "Your ticket":#{Rails.application.routes.url_helpers.ticket_path(self)} has been updated by #{handler.pretty_name}.
        Ticket Status: #{status}

        Response: #{response}
      MSG
      Dmail.create_split(
        from_id: CurrentUser.id,
        to_id: creator.id,
        title: "Your ticket has been updated#{" to #{status}" if saved_change_to_status?}",
        body: msg,
        bypass_limits: true,
      )
    end

    def log_update
      return unless saved_change_to_response? || saved_change_to_status?

      ModAction.log(:ticket_update, { ticket_id: id, status: status, response: response, status_was: status_before_last_save, response_was: response_before_last_save })
    end
  end

  module PubSubMethods
    def pubsub_hash(action)
      {
        action: action,
        ticket: {
          id: id,
          user_id: creator_id,
          user: creator_id ? User.id_to_name(creator_id) : nil,
          claimant: claimant_id ? User.id_to_name(claimant_id) : nil,
          target: bot_target_name,
          target_id: disp_id,
          accused_id: accused_id,
          status: status,
          category: qtype,
          reason: reason,
        },
      }
    end

    def push_pubsub(action)
      Cache.redis.publish("ticket_updates", pubsub_hash(action).to_json)
    end

    def push_pubsub_create
      push_pubsub("create")
    end

    def push_pubsub_update_notification
      push_pubsub("update") if saved_change_to_status? || saved_change_to_response?
    end
  end

  include ClassifyMethods
  include ValidationMethods
  include APIMethods
  include ClaimMethods
  include NotificationMethods
  include PubSubMethods
  extend SearchMethods
end
