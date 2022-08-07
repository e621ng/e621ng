class Ticket < ApplicationRecord
  belongs_to_creator
  belongs_to :claimant, class_name: "User", optional: true
  belongs_to :handler, class_name: "User", optional: true
  before_validation :initialize_fields, on: :create
  after_initialize :validate_type
  after_initialize :classify
  validates :qtype, presence: true
  validates :reason, presence: true
  validates :reason, length: { minimum: 2, maximum: Danbooru.config.ticket_max_size }
  after_update :log_update, if: :should_send_notification
  after_update :send_update_dmail, if: :should_send_notification
  validate :validate_content_exists, on: :create
  validate :validate_can_see_target, on: :create
  validate :validate_creator_is_not_limited, on: :create

  scope :for_creator, ->(uid) {where('creator_id = ?', uid)}

=begin
    Permission truth table.
    Type            | Field         | Access
    -----------------------------------------
    Any             | Username      | Admin+ / Current User
    Name Change     | Old Nme       | Any
    Any             | Created At    | Any
    Any             | Updated At    | Any
    Any             | Claimed By    | Admin+
    Any             | Status        | Any
    Any             | IP Address    | Admin+
    User Complaint  | Reported User | Admin+ / Current User
    Dmail           | Details       | Admin+ / Current User
    Comment         | Comment Link  | Any
    Comment         | Comment Author| Any
    Forum           | Forum Post    | Forum Visibility / Any
    Wiki            | Wiki Page     | Any
    Blip            | Blip          | Any
    Pool            | Pool          | Any
    Set             | Set           | Any
    Other           | Any           | N/A(No details shown)
    Name Change     | Desired Name  | Any
    DMail           | Reason        | Admin+ / Current User
    User Complaint  | Reason        | Admin+ / Current User
    Any             | Reason        | Any
    DMail           | Response      | Admin+ / Current User
    User Complaint  | Response      | Admin+ / Current User
    Any             | Response      | Any
    Any             | Handled By    | Any
=end

  module TicketTypes
    module ForumType
      def model
        ::ForumPost
      end

      def can_create_for?(user)
        content.visible?(user)
      end

      def can_see_details?(user)
        if content
          content.visible?(user)
        else
          true
        end
      end
    end

    module CommentType
      def model
        ::Comment
      end

      def can_create_for?(user)
        content.visible_to?(user)
      end
    end

    module DmailType
      def self.extended(m)
        m.class_eval do
          validate :validate_report_allowed

          def validate_report_allowed
            if content&.owner_id != creator_id
              errors.add :dmail, "does not exist"
            end
            if content&.to_id != creator_id
              errors.add :dmail, "must be a dmail you received"
            end
          end
        end
      end

      def model
        ::Dmail
      end

      def can_create_for?(user)
        content.visible_to?(user) && content.to_id == user.id
      end

      def can_see_details?(user)
        user.is_admin? || (user.id == creator_id)
      end

      def can_see_reason?(user)
        can_see_details?(user)
      end

      def can_see_response?(user)
        can_see_details?(user)
      end
    end

    module WikiType
      def model
        ::WikiPage
      end

      def can_create_for?(user)
        true
      end
    end

    module PoolType
      def model
        ::Pool
      end

      def can_create_for?(user)
        true
      end
    end

    module SetType
      def model
        ::PostSet
      end

      def can_create_for?(user)
        content.can_view?(user)
      end
    end

    module PostType
      def self.extended(m)
        m.class_eval do
          validates :report_reason, presence: true
        end
      end

      def subject
        reason.split("\n")[0] || "Unknown Report Type"
      end

      def model
        ::Post
      end

      def can_create_for?(user)
        true
      end
    end

    module BlipType
      def model
        ::Blip
      end

      def can_create_for?(user)
        content.visible_to?(user)
      end
    end

    module UserType
      def model
        ::User
      end

      def can_create_for?(user)
        true
      end

      def can_see_details?(user)
        user.is_admin? || user.id == creator_id
      end

      def can_see_reason?(user)
        can_see_details?(user)
      end

      def can_see_response?(user)
        can_see_details?(user)
      end
    end
  end

  module APIMethods
    def hidden_attributes
      hidden = []
      hidden += %i[claimant_id] unless CurrentUser.is_admin?
      hidden += %i[creator_id] unless can_see_username?(CurrentUser)
      hidden += %i[disp_id] unless can_see_details?(CurrentUser)
      hidden += %i[reason] unless can_see_reason?(CurrentUser)
      super + hidden
    end
  end

  VALID_STATUSES = %w(pending partial denied approved)
  TYPE_MAP = {
      'forum' => TicketTypes::ForumType,
      'comment' => TicketTypes::CommentType,
      'blip' => TicketTypes::BlipType,
      'user' => TicketTypes::UserType,
      'dmail' => TicketTypes::DmailType,
      'wiki' => TicketTypes::WikiType,
      'pool' => TicketTypes::PoolType,
      'set' => TicketTypes::SetType,
      'post' => TicketTypes::PostType
  }

  attr_reader :can_see, :type_valid

  module ValidationMethods
    def validate_type
      unless TYPE_MAP.key?(qtype)
        errors.add(:qtype, "is not valid")
        @type_valid = false
      else
        @type_valid = true
      end
    end

    def validate_can_see_target(user = CurrentUser.user)
      unless can_create_for?(user)
        errors.add(:base, "You can not report this content because you can not see it.")
        @can_see = false
      else
        @can_see = true
      end
    end

    def validate_creator_is_not_limited
      allowed = creator.can_ticket_with_reason
      if allowed != true
        errors.add(:creator, User.throttle_reason(allowed))
        return false
      end
      true
    end

    def validate_content_exists
      errors.add model.name.underscore.to_sym, "does not exist" if content.nil?
    end

    def initialize_fields
      self.status = 'pending'
    end
  end

  module SearchMethods
    def search(params)
      q = super.includes(:creator).includes(:claimant)

      if params[:creator_id].present?
        q = q.where('creator_id = ?', params[:creator_id].to_i)
      end

      if params[:claimant_id].present?
        q = q.where('claimant_id = ?', params[:claimant_id].to_i)
      end

      if params[:creator_name].present?
        user_id = User.name_to_id(params[:creator_name])
        q = q.where('creator_id = ?', user_id) if user_id
      end

      if params[:accused_name].present?
        user_id = User.name_to_id(params[:accused_name])
        q = q.where('disp_id = ? and qtype = ?', user_id, 'user') if user_id
      end

      if params[:type].present?
        q = q.where('qtype = ?', params[:type])
      end

      if params[:reason].present?
        q = q.attribute_matches(:reason, params[:reason])
      end

      if params[:status].present?
        case params[:status]
        when "pending_claimed"
          q = q.where('status = ? and claimant_id is not null', 'pending')
        when "pending_unclaimed"
          q = q.where('status = ? and claimant_id is null', 'pending')
        else
          q = q.where('status = ?', params[:status])
        end
      end

      q.order(Arel.sql("CASE status WHEN 'pending' THEN 0 WHEN 'partial' THEN 1 ELSE 2 END ASC, id DESC"))
    end
  end

  module ClassifyMethods
    def classify
      klass = TYPE_MAP[qtype]
      extend(klass) if klass
    end
  end

  def content=(new_content)
    @content = new_content
    self.disp_id = content&.id
  end

  def content
    @content ||= model.find_by(id: disp_id)
  end

  def can_see_reason?(user)
    true
  end

  def can_see_details?(user)
    true
  end

  def can_see_username?(user)
    user.is_admin? || (user.id == creator_id)
  end

  def can_see_response?(user)
    true
  end

  def can_create_for?(user)
    false
  end

  def type_title
    "#{model.name.titlecase} Complaint"
  end

  def subject
    if reason.length > 40
      "#{reason[0, 38]}..."
    else
      reason
    end
  end

  def open_duplicates
    Ticket.where('qtype = ? and disp_id = ? and status = ?', qtype, disp_id, 'pending')
  end

  module ClaimMethods
    def claim!(user = CurrentUser)
      transaction do
        ModAction.log(:ticket_claim, {ticket_id: id})
        update_attribute(:claimant_id, user.id)
      end
    end

    def unclaim!(user = CurrentUser)
      transaction do
        ModAction.log(:ticket_unclaim, {ticket_id: id})
        update_attribute(:claimant_id, nil)
      end
    end
  end

  module NotificationMethods
    def should_send_notification
      saved_change_to_status?
    end

    def send_update_dmail
      msg = "\"Your ticket\":#{Rails.application.routes.url_helpers.ticket_path(self)} has been updated by" +
          " #{handler.pretty_name}.\nTicket Status: #{status}\n\n" +
          (qtype == "reason" ? "Reason" : "Response") +
          ": #{response}"
      Dmail.create_split(
          :from_id => CurrentUser.id,
          :to_id => creator.id,
          :title => "Your ticket has been updated to '#{status}'",
          :body => msg,
          bypass_limits: true
      )
    end

    def log_update
      ModAction.log(:ticket_update, {ticket_id: id})
    end
  end

  include ClassifyMethods
  include ValidationMethods
  include APIMethods
  include ClaimMethods
  include NotificationMethods
  extend SearchMethods
end
