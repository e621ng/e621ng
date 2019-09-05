require 'ticket/type_methods'
class Ticket < ApplicationRecord
  belongs_to_creator
  belongs_to :claimant, class_name: "User", optional: true
  belongs_to :handler, class_name: "User", optional: true
  before_validation :initialize_fields, on: :create
  after_initialize :validate_type
  after_initialize :classify
  validates_presence_of :qtype
  validates_presence_of :reason
  validates_length_of :reason, maximum: 5_000
  after_update :log_update, if: :should_send_notification
  after_update :send_update_dmail, if: :should_send_notification
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
      'namechange' => TicketTypes::NamechangeType,
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
        q = q.where('tickets.creator_id = (select _.id from users _ where lower(_.name) = ?', params[:reporter_name].tr(' ', '_').downcase)
      end

      if params[:accused].present?
        q = q.where("tickets.disp_id = (select _.id from users _ where lower(_.name) = ? AND tickets.qtype = ?)", params[:accused].tr(' ', '_').downcase, 'user')
      end

      if params[:type].present?
        q = q.where('qtype = ?', params[:type])
      end

      if params[:status].present?
        q = q.where('status = ?', params[:status])
      end



      q.apply_default_order(params)
    end
  end

  module ClassifyMethods
    def classify
      klass = TYPE_MAP.fetch(qtype, TicketTypes::DefaultType)
      self.extend(klass)
      klass.after_extended(self)
    end
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
    'Ticket'
  end

  def subject
    if reason.length > 40
      "#{reason[0, 38]}..."
    else
      reason
    end
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
      status_changed?
    end

    def send_update_dmail
      msg = "\"Your ticket\":#{Rails.application.routes.url_helpers.ticket_path(self)} has been updated by" +
          " #{handler.pretty_name}.\nTicket Status: #{status}\n\n" +
          (qtype == "reason" ? "Reason" : "Response") +
          ": #{response}"
      Dmail.create_automated(
          :to_id => user.id,
          :title => "Your ticket has been updated to '#{pretty_status}'",
          :body => msg
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
