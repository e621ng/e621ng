class Ticket < ApplicationRecord
  belongs_to_creator
  belongs_to :claimant, class_name: "User", optional: true
  belongs_to :handler, class_name: "User", optional: true
  before_validation :initialize_fields, on: :create
  after_initialize :validate_type
  after_initialize :classify
  validates :qtype, presence: true
  validates :reason, presence: true
  validates :reason, length: { minimum: 2, maximum: 5_000 }
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

  module TicketTypes
    module DefaultType
      def type_title
        "Ticket"
      end

      def self.after_extended(m)
        m
      end
    end

    module NamechangeType
      def self.after_extended(m)
        m.class_eval do
          attr_accessor :no_name_change
          validate :validate_on_create, on: :create
          before_save :before_save
        end
        m.oldname = m.user.name if m.oldname.blank?
        m.no_name_change = false
      end

      # Required to override default ("Investigated")
      def pretty_status
        status.titleize
      end

      def subject
        "Requested Name: #{reason}"
      end

      def before_save
        super
        if change_username?
          return false unless username_valid?
          change_username
        end
        true
      end

      def username_valid?
        if ::User.find_by_name(requested_name)
          errors.add :requested_name, "is already taken."
          return false
        end
        true
      end

      def change_username?
        status_was == 'pending' and status == 'approved' and not no_name_change
      end

      def change_username
        ::Ticket.transaction do
          user.name = requested_name
          user.save
          user.errors.each {|k, v| errors.add k, v}
          ::Namechange.create(mod: admin, user_id: user_id,
                            oldname: oldname, newname: reason)
        end
      end

      def requested_name
        reason
      end

      def type_title
        'Change Username'
      end

      def validate_on_create
        errors.add :user, "doesn't even exist" unless user
        errors.add :you, "can only create one namechange request per week" if Ticket.first(
            order: created_at,
            conditions: ["qtype = ? AND user_id = ? AND created_at > ?", "namechange", user.id, 1.week.ago])
        errors.add :requested_name, "is taken" if User.find_by_name(requested_name)


        if admin.nil? or status == 'approved'
          user.name = reason
          user.valid?
          user.errors.each do |key, value|
            errors.add key, value
          end
          user.reload
        end
      end

      def can_see_username?(user)
        true
      end

      def can_create_for?(user)
        false # use other name change system now, not tickets
      end
    end

    module ForumType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Forum Post Complaint'
      end

      def validate_on_create
        if forum.nil?
          errors.add :forum, "post does not exist"
        end
      end

      def forum=(new_forum)
        @forum = new_forum
        self.disp_id = new_forum.id unless new_forum.nil?
      end

      def forum
        @forum ||= begin
          ::ForumPost.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        forum.visible?(user)
      end

      def can_see_details?(user)
        if forum
          forum.visible?(user)
        else
          true
        end
      end
    end

    module CommentType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Comment Complaint'
      end

      def validate_on_create
        if comment.nil?
          errors.add :comment, "does not exist"
        end
      end

      def comment=(new_comment)
        @comment = new_comment
        self.disp_id = new_comment.id unless new_comment.nil?
      end

      def comment
        @comment ||= begin
          ::Comment.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        comment.visible_to?(user)
      end
    end

    module DmailType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Dmail Complaint'
      end

      def validate_on_create
        unless dmail and dmail.owner_id == creator_id
          errors.add :dmail, "does not exist"
        end
      end

      def dmail=(new_dmail)
        @dmail = new_dmail
        self.disp_id = new_dmail.id unless new_dmail.nil?
      end

      def dmail
        @dmail ||= begin
          ::Dmail.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        dmail.visible_to?(user)
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
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Wiki Page Complaint'
      end

      def validate_on_create
        if wiki.nil?
          errors.add :wiki, "page does not exist"
        end
      end

      def wiki=(new_wiki)
        @wiki = new_wiki
        self.disp_id = new_wiki.id unless new_wiki.nil?
      end

      def wiki
        @wiki ||= begin
          ::WikiPage.find disp_id unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        true
      end
    end

    module PoolType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Pool Complaint'
      end

      def validate_on_create
        if pool.nil?
          errors.add :pool, "does not exist"
        end
      end

      def pool=(new_pool)
        @pool = new_pool
        self.disp_id = new_pool.id unless new_pool.nil?
      end

      def pool
        @pool ||= begin
          ::Pool.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        true
      end
    end

    module SetType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Set Complaint'
      end

      def validate_on_create
        if set.nil?
          errors.add :set, "does not exist"
        end
      end

      def set=(new_set)
        @set = new_set
        self.disp_id = new_set.id unless new_set.nil?
      end

      def set
        @set ||= begin
          ::PostSet.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        set.can_view?(user)
      end
    end

    module PostType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Post Complaint'
      end

      def validate_on_create
        if post.nil?
          errors.add :post, "does not exist"
        end
        if report_reason.blank?
          errors.add :report_reason, "does not exist"
        end
      end

      def subject
        reason.split("\n")[0] || "Unknown Report Type"
      end

      def post=(new_post)
        @post = new_post
        self.disp_id = new_post.id unless new_post.nil?
      end

      def post
        @post ||= begin
          ::Post.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        true
      end
    end

    module BlipType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'Blip Complaint'
      end

      def validate_on_create
        if blip.nil?
          errors.add :blip, "does not exist"
        end
      end

      def blip=(new_blip)
        @blip = new_blip
        self.disp_id = new_blip.id unless new_blip.nil?
      end

      def blip
        @blip ||= begin
          ::Blip.find(disp_id) unless disp_id.nil?
        rescue
        end
      end

      def can_create_for?(user)
        blip.visible_to?(user)
      end
    end

    module UserType
      def self.after_extended(m)
        m.class_eval do
          validate :validate_on_create, on: :create
        end
        m
      end

      def type_title
        'User Complaint'
      end

      def validate_on_create
        if accused.nil?
          errors.add :user, "does not exist"
        end
      end

      def accused=(new_accused)
        @accused = new_accused
        self.disp_id = new_accused.id unless new_accused.nil?
      end

      def accused
        @accused ||= begin
          ::User.find(disp_id) unless disp_id.nil?
        rescue
        end
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
      q = q.where('qtype != ?', 'namechange')

      if params[:creator_id].present?
        q = q.where('creator_id = ?', params[:creator_id].to_i)
      end

      if params[:claimant_id].present?
        q = q.where('claimant_id = ?', params[:claimant_id].to_i)
      end

      if params[:creator_name].present?
        user_id = User::name_to_id(params[:creator_name])
        q = q.where('creator_id = ?', user_id) if user_id
      end

      if params[:accused].present?
        user_id = User::name_to_id(params[:accused])
        q = q.where('disp_id = ? and qtype = ?', [user_id, 'user']) if user_id
      end

      if params[:type].present?
        q = q.where('qtype = ?', params[:type])
      end

      if params[:status].present?
        q = q.where('status = ?', params[:status])
      end



      q.order(Arel.sql("CASE status WHEN 'pending' THEN 0 WHEN 'partial' THEN 1 ELSE 2 END ASC, id DESC"))
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
