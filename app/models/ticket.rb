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
    module Forum
      # FIXME: Remove this by renaming the qtype value to the correct one
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

    module Comment
      def can_create_for?(user)
        content.visible_to?(user)
      end
    end

    module Dmail
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

    module Wiki
      def model
        ::WikiPage
      end

      def can_create_for?(user)
        true
      end
    end

    module Pool
      def can_create_for?(user)
        true
      end
    end

    module Set
      def model
        ::PostSet
      end

      def can_create_for?(user)
        content.can_view?(user)
      end
    end

    module Post
      def self.extended(m)
        m.class_eval do
          validates :report_reason, presence: true
        end
      end

      def subject
        reason.split("\n")[0] || "Unknown Report Type"
      end

      def can_create_for?(user)
        true
      end
    end

    module Blip
      def can_create_for?(user)
        content.visible_to?(user)
      end
    end

    module User
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

  module ValidationMethods
    def validate_type
      valid_types = TicketTypes.constants.map { |v| v.to_s.downcase }
      errors.add(:qtype, "is not valid") if valid_types.exclude?(qtype)
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
      extend(TicketTypes.const_get(qtype.classify)) if TicketTypes.const_defined?(qtype.classify)
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

  def model
    qtype.classify.constantize
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
