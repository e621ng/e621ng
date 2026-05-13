# frozen_string_literal: true

class Appeal < ApplicationRecord
  belongs_to_creator
  user_status_counter :appeal_count
  belongs_to :claimant, class_name: "User", optional: true
  belongs_to :handler, class_name: "User", optional: true
  belongs_to :accused, class_name: "User", optional: true
  after_initialize :classify
  before_validation :initialize_fields, on: :create
  normalizes :reason, with: ->(reason) { reason.gsub("\r\n", "\n") }
  validates :qtype, presence: true
  validate :validate_type
  validates :reason, presence: true
  validates :reason, length: { minimum: 2, maximum: Danbooru.config.ticket_max_size }
  validates :response, length: { minimum: 2, maximum: Danbooru.config.dmail_max_size }, on: :update
  enum :status, %i[pending partial approved].index_with(&:to_s)
  after_create :push_pubsub_create
  after_update :push_pubsub_update_notification
  after_update :log_update
  after_update :create_dmail
  validate :validate_content_exists, on: :create
  validate :validate_creator_is_not_limited, on: :create

  scope :for_creator, ->(uid) { where("creator_id = ?", uid) }

  attr_accessor :send_update_dmail

  # Permissions Table
  # Creator can always view their own appeals. Admin always has unconditional view access.
  # For content-gated types, staff can view even if the content no longer exists.
  #
  # |    Type    |      Can Create     |  Min. View Level  | View Content Check |
  # |:----------:|:-------------------:|:-----------------:|:------------------:|
  # |  PostFlag  |      Accessible     |     Janitor+      |     Accessible     |
  # |    Other   |         None        |    Moderator+     |        -           |

  module AppealTypes
    module Flag
      def model
        ::PostFlag
      end

      def can_create_for?(user)
        return false if content.blank?
        return false if content.post.blank?
        return false unless content.post.uploader_id == user.id
        true
      end

      def can_view?(user = CurrentUser.user)
        return true if user.is_staff?
        return true if user.id == creator_id
        false
      end
    end
  end

  VALID_QTYPES = AppealTypes.constants.map { |c| c.to_s.downcase }.freeze

  module APIMethods
    def hidden_attributes
      hidden = []

      unless can_view?(CurrentUser.user)
        hidden += %i[creator_id accused_id reason response]
        return super + hidden
      end

      hidden += %i[claimant_id] unless CurrentUser.is_staff?
      super + hidden
    end
  end

  module ValidationMethods
    def validate_type
      errors.add(:qtype, "is not valid") if VALID_QTYPES.exclude?(qtype)
    end

    def validate_creator_is_not_limited
      return if creator == User.system

      # Hourly limit
      hourly_allowed = creator.can_appeal_hourly_with_reason
      if hourly_allowed != true
        errors.add(:creator, User.throttle_reason(hourly_allowed, "hourly"))
        return false
      end

      # Daily limit
      daily_allowed = creator.can_appeal_daily_with_reason
      if daily_allowed != true
        errors.add(:creator, User.throttle_reason(daily_allowed, "daily"))
        return false
      end

      # Active limit
      active_allowed = creator.can_appeal_active_with_reason
      if active_allowed != true
        errors.add(:creator, User.throttle_reason(active_allowed, "active"))
        return false
      end

      true
    end

    def validate_content_exists
      return if qtype.blank?
      return if errors[:qtype].any? # qtype invalid, cannot validate content
      errors.add model.name.underscore.to_sym, "does not exist" if content.nil?
    end

    def initialize_fields
      self.status = "pending"
      case qtype
      when "flag"
        flag = content
        if flag.present?
          self.accused_id = flag.creator_id
        else
          errors.add model.name.underscore.to_sym, "does not exist"
        end
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
      if user.is_janitor?
        all
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
      extend(AppealTypes.const_get(qtype.camelize)) if AppealTypes.constants.map(&:to_s).include?(qtype&.camelize)
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
    return true if user.is_janitor?
    return true if user.id == creator_id
    false
  end

  def can_handle?(user = CurrentUser.user)
    user.is_janitor?
  end

  def can_claim?(user = CurrentUser.user)
    user.is_janitor?
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

  def pretty_status
    case status
    when "partial"
      "Under Investigation"
    when "approved"
      "Investigated"
    else
      status.titleize
    end
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
    Appeal.where(
      qtype: qtype,
      disp_id: disp_id,
      status: "pending",
    ).where.not(id: id)
  end

  def open_from_same_user
    @open_from_same_user ||= Appeal.where(
      creator_id: creator_id,
      status: %w[pending partial],
    ).where.not(id: id)
  end

  module ClaimMethods
    def claim!(user = CurrentUser)
      transaction do
        ModAction.log(:appeal_claim, { appeal_id: id })
        update_attribute(:claimant_id, user.id)
        push_pubsub("claim")
      end
    end

    def unclaim!(_user = CurrentUser)
      transaction do
        ModAction.log(:appeal_unclaim, { appeal_id: id })
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
        "Your appeal":#{Rails.application.routes.url_helpers.appeal_path(self)} has been updated by #{handler.pretty_name}.
        Appeal Status: #{pretty_status}

        Response: #{response}
      MSG
      Dmail.create_split(
        from_id: CurrentUser.id,
        to_id: creator.id,
        title: "Your appeal has been updated#{" to #{pretty_status}" if saved_change_to_status?}",
        body: msg,
        bypass_limits: true,
      )
    end

    def log_update
      return unless saved_change_to_response? || saved_change_to_status?

      ModAction.log(:appeal_update, { appeal_id: id, status: status, response: response, status_was: status_before_last_save, response_was: response_before_last_save })
    end
  end

  module PubSubMethods
    def pubsub_hash(action)
      {
        action: action,
        appeal: {
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
      Cache.redis.publish("appeal_updates", pubsub_hash(action).to_json)
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
