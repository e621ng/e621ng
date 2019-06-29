require 'digest/sha1'
require 'danbooru/has_bit_flags'

class User < ApplicationRecord
  class Error < Exception ; end
  class PrivilegeError < Exception
    attr_accessor :message

    def initialize(msg = nil)
      @message = "Access Denied: #{msg}" if msg
    end
  end

  module Levels
    ANONYMOUS = 0
    BLOCKED = 10
    MEMBER = 20
    PRIVILEGED = 30
    CONTRIBUTOR = 33
    FORMER_STAFF = 34
    JANITOR = 35
    MODERATOR = 40
    ADMIN = 50
  end

  # Used for `before_action :<role>_only`. Must have a corresponding `is_<role>?` method.
  Roles = Levels.constants.map(&:downcase) + [
    :banned,
    :approver,
    :voter,
    :verified,
  ]

  # candidates for removal:
  # - disable_cropped_thumbnails (enabled by 22)
  BOOLEAN_ATTRIBUTES = %w(
    show_avatars
    blacklist_avatars
    blacklist_users
    description_collapsed_initially
    hide_comments
    show_hidden_comments
    show_post_statistics
    is_banned
    has_mail
    receive_email_notifications
    enable_keyboard_navigation
    enable_privacy_mode
    style_usernames
    enable_auto_complete
    has_saved_searches
    can_approve_posts
    can_upload_free
    disable_cropped_thumbnails
    disable_mobile_gestures
    enable_safe_mode
    disable_responsive_mode
    disable_post_tooltips
    no_flagging
    no_feedback
  )

  include Danbooru::HasBitFlags
  has_bit_flags BOOLEAN_ATTRIBUTES, :field => "bit_prefs"

  attr_accessor :password, :old_password

  after_initialize :initialize_attributes, if: :new_record?
  validates :name, user_name: true, on: :create
  validates_uniqueness_of :email, :case_sensitive => false, :if => ->(rec) { rec.email.present? && rec.saved_change_to_email? }
  validate :validate_email_address_allowed, on: [:create, :save], if: ->(rec) { (rec.new_record? && rec.email.present?) || (rec.email.present? && rec.saved_change_to_email?) }
  validates_length_of :password, :minimum => 5, :if => ->(rec) { rec.new_record? || rec.password.present?}
  validates_inclusion_of :default_image_size, :in => %w(large fit original)
  validates_inclusion_of :per_page, :in => 1..250
  validates_confirmation_of :password
  validates_presence_of :email, :if => ->(rec) { rec.new_record? && Danbooru.config.enable_email_verification?}
  validates_presence_of :comment_threshold
  validate :validate_ip_addr_is_not_banned, :on => :create
  validate :validate_sock_puppets, :on => :create, :if => -> { Danbooru.config.enable_sock_puppet_validation? }
  before_validation :normalize_blacklisted_tags
  before_validation :set_per_page
  before_validation :normalize_email
  before_create :encrypt_password_on_create
  before_update :encrypt_password_on_update
  after_save :update_cache
  before_create :promote_to_admin_if_first_user
  before_create :customize_new_user
  #after_create :notify_sock_puppets
  after_create :create_user_status
  has_many :feedback, :class_name => "UserFeedback", :dependent => :destroy
  has_many :posts, :foreign_key => "uploader_id"
  has_many :post_approvals, :dependent => :destroy
  has_many :post_disapprovals, :dependent => :destroy
  has_many :post_votes
  has_many :post_archives
  has_many :note_versions
  has_many :bans, -> {order("bans.id desc")}
  has_one :recent_ban, -> {order("bans.id desc")}, :class_name => "Ban"
  has_one :user_status

  has_one :api_key
  has_one :dmail_filter
  has_many :note_versions, :foreign_key => "updater_id"
  has_many :dmails, -> {order("dmails.id desc")}, :foreign_key => "owner_id"
  has_many :saved_searches
  has_many :forum_posts, -> {order("forum_posts.created_at, forum_posts.id")}, :foreign_key => "creator_id"
  has_many :user_name_change_requests, -> {visible.order("user_name_change_requests.created_at desc")}
  has_many :post_sets, -> {order(name: :asc)}, foreign_key: :creator_id
  has_many :favorites, ->(rec) {where("user_id % 100 = #{rec.id % 100} and user_id = #{rec.id}").order("id desc")}
  belongs_to :inviter, class_name: "User", optional: true
  belongs_to :avatar, class_name: 'Post', optional: true
  accepts_nested_attributes_for :dmail_filter

  module BanMethods
    def validate_ip_addr_is_not_banned
      if IpBan.is_banned?(CurrentUser.ip_addr)
        self.errors[:base] << "IP address is banned"
        return false
      end
    end

    def unban!
      self.is_banned = false
      save
    end

    def ban_expired?
      is_banned? && recent_ban.try(:expired?)
    end
  end

  module NameMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def name_to_id(name)
        Cache.get("uni:#{Cache.hash(name)}", 4.hours) do
          val = select_value_sql("SELECT id FROM users WHERE lower(name) = ?", name.mb_chars.downcase.tr(" ", "_").to_s)
          if val.present?
            val.to_i
          else
            nil
          end
        end
      end

      def id_to_name(user_id)
        Cache.get("uin:#{user_id}", 4.hours) do
          select_value_sql("SELECT name FROM users WHERE id = ?", user_id) || Danbooru.config.default_guest_name
        end
      end

      def find_by_name(name)
        where("lower(name) = ?", name.mb_chars.downcase.tr(" ", "_")).first
      end

      def id_to_pretty_name(user_id)
        id_to_name(user_id).gsub(/([^_])_+(?=[^_])/, "\\1 \\2")
      end

      def normalize_name(name)
        name.to_s.mb_chars.downcase.strip.tr(" ", "_").to_s
      end
    end

    def pretty_name
      name.gsub(/([^_])_+(?=[^_])/, "\\1 \\2")
    end

    def update_cache
      Cache.put("uin:#{id}", name, 4.hours)
      Cache.put("uni:#{Cache.hash(name)}", id, 4.hours)
    end
  end

  module PasswordMethods
    def bcrypt_password
      BCrypt::Password.new(bcrypt_password_hash)
    end

    def encrypt_password_on_create
      self.password_hash = ""
      self.bcrypt_password_hash = User.bcrypt(password)
    end

    def encrypt_password_on_update
      return if password.blank?
      return if old_password.blank?

      if bcrypt_password == old_password
        self.bcrypt_password_hash = User.bcrypt(password)
        return true
      else
        errors[:old_password] << "is incorrect"
        return false
      end
    end

    def upgrade_password(pass)
      self.update_columns(password_hash: '', bcrypt_password_hash: User.bcrypt(pass))
    end
  end

  module AuthenticationMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def authenticate(name, pass)
        user = find_by_name(name)
        if user && user.password_hash.present? && PBKDF2.validate_password(pass, user.password_hash)
          user.upgrade_password(pass)
          user
        elsif user && user.bcrypt_password_hash && user.bcrypt_password == pass
          user
        else
          nil
        end
      end

      def authenticate_api_key(name, api_key)
        key = ApiKey.where(:key => api_key).first
        return nil if key.nil?
        user = find_by_name(name)
        return nil if user.nil?
        return user if key.user_id == user.id
        nil
      end

      def bcrypt(pass)
        BCrypt::Password.create(pass)
      end
    end
  end

  module LevelMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def system
        User.find_by!(name: Danbooru.config.system_user)
      end

      def anonymous
        user = User.new(name: "Anonymous", created_at: Time.now)
        user.freeze.readonly!
        user
      end

      def level_hash
        return {
          "Member" => Levels::MEMBER,
          "Privileged" => Levels::PRIVILEGED,
          "Platinum" => Levels::CONTRIBUTOR,
          "Builder" => Levels::JANITOR,
          "Moderator" => Levels::MODERATOR,
          "Admin" => Levels::ADMIN
        }
      end

      def level_string(value)
        case value
        when Levels::ANONYMOUS
          "Anonymous"

        when Levels::BLOCKED
          "Banned"

        when Levels::MEMBER
          "Member"

        when Levels::JANITOR
          "Builder"

        when Levels::PRIVILEGED
          "Privileged"

        when Levels::CONTRIBUTOR
          "Platinum"

        when Levels::MODERATOR
          "Moderator"

        when Levels::ADMIN
          "Admin"

        else
          ""
        end
      end
    end

    def promote_to!(new_level, options = {})
      UserPromotion.new(self, CurrentUser.user, new_level, options).promote!
    end

    def promote_to_admin_if_first_user
      return if Rails.env.test?

      if User.admins.count == 0
        self.level = Levels::ADMIN
        self.can_approve_posts = true
        self.can_upload_free = true
      else
        self.level = Levels::MEMBER
      end
    end

    def customize_new_user
      Danbooru.config.customize_new_user(self)
    end

    def role
      level_string.downcase.to_sym
    end

    def level_string_was
      level_string(level_was)
    end

    def level_string(value = nil)
      User.level_string(value || level)
    end

    def is_anonymous?
      level == Levels::ANONYMOUS
    end

    def is_member?
      level >= Levels::MEMBER
    end

    def is_blocked?
      is_banned?
    end

    def is_builder?
      level >= Levels::JANITOR
    end

    def is_privileged?
      level >= Levels::PRIVILEGED
    end

    def is_platinum?
      level >= Levels::CONTRIBUTOR
    end

    def is_moderator?
      level >= Levels::MODERATOR
    end

    def is_mod?
      level >= Levels::MODERATOR
    end

    def is_admin?
      level >= Levels::ADMIN
    end

    def is_voter?
      is_member?
    end

    def is_approver?
      can_approve_posts?
    end

    def set_per_page
      if per_page.nil?
        self.per_page = Danbooru.config.posts_per_page
      end

      return true
    end

    def level_class
      "user-#{level_string.downcase}"
    end

    def create_user_status
      UserStatus.create!(user_id: id)
    end
  end

  module EmailMethods
    def is_verified?
      email_verification_key.blank?
    end

    def generate_email_verification_key
      self.email_verification_key = Digest::SHA1.hexdigest("#{Time.now.to_f}--#{name}--#{rand(1_000_000)}--")
    end

    def verify!(key)
      if email_verification_key == key
        self.update_column(:email_verification_key, nil)
      else
        raise User::Error.new("Verification key does not match")
      end
    end

    def normalize_email
      self.email = nil if email.blank?
    end

    def validate_email_address_allowed
      if EmailBlacklist.is_banned?(self.email)
        self.errors[:base] << "Email address may not be used"
        return false
      end
    end
  end

  module BlacklistMethods
    def normalize_blacklisted_tags
      self.blacklisted_tags = blacklisted_tags.downcase if blacklisted_tags.present?
    end
  end

  module ForumMethods
    def has_forum_been_updated?
      # TODO: Review this line, it doesn't make sense?
      return false unless is_privileged?
      max_updated_at = ForumTopic.permitted.active.maximum(:updated_at)
      return false if max_updated_at.nil?
      return true if last_forum_read_at.nil?
      return max_updated_at > last_forum_read_at
    end
  end

  module ThrottleMethods
    def throttle_reason(reason)
      reasons = {
          REJ_NEWBIE: 'can not yet perform this action. User not old enough',
          REJ_LIMITED: 'has reached the hourly limit for this action'
      }
      reasons.fetch(reason, 'unknown throttle reason, please report this as a bug')
    end

    def upload_reason_string(reason)
      reasons = {
          REJ_UPLOAD_HOURLY: "have reached your hourly upload limit",
          REJ_UPLOAD_EDIT: "have no remaining tag edits available",
          REJ_UPLOAD_LIMIT: "have reached your upload limit",
          REJ_UPLOAD_NEWBIE: "cannot upload during your first week"
      }
      reasons.fetch(reason, "unknown upload rejection reason")
    end
  end

  module LimitMethods
    extend Memoist

    def self.create_user_throttle(name, limiter, checker, newbie_duration)
      define_method("#{name}_limit".to_sym, limiter)
      memoize "#{name}_limit".to_sym
      define_method("can_#{name}_with_reason".to_sym) do
        return :REJ_NEWBIE if newbie_duration && created_at > newbie_duration
        return send(checker) if checker && send(checker)
        return :REJ_LIMITED if send("#{name}_limit") <= 0
        true
      end
    end

    def token_bucket
      @token_bucket ||= UserThrottle.new({prefix: "thtl:", duration: 1.minute}, self)
    end

    def general_should_throttle?
      !is_platinum?
    end

    create_user_throttle(:artist_edit, ->{ Danbooru.config.artist_edit_limit - ArtistVersion.for_user(id).where('updated_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 7.days.ago)
    create_user_throttle(:post_edit, ->{ Danbooru.config.post_edit_limit - PostArchive.for_user(id).where('updated_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 3.days.ago)
    create_user_throttle(:wiki_edit, ->{ Danbooru.config.wiki_edit_limit - WikiPageVersion.for_user(id).where('updated_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 7.days.ago)
    create_user_throttle(:pool, ->{ Danbooru.config.pool_limit - Pool.for_user(id).where('created_at > ?', 1.hour.ago).count },
                         nil, 7.days.ago)
    create_user_throttle(:pool_edit, ->{ Danbooru.config.pool_edit_limit - PoolArchive.for_user(id).where('updated_at > ?', 1.hour.ago).count },
                         nil, 7.days.ago)
    create_user_throttle(:note_edit, ->{ Danbooru.config.note_edit_limit - NoteVersion.for_user(id).where('updated_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 7.days.ago)
    create_user_throttle(:comment, ->{ Danbooru.config.member_comment_limit - Comment.for_creator(id).where('created_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 7.days.ago)
    create_user_throttle(:blip, ->{ Danbooru.config.blip_limit - Blip.for_creator(id).where('created_at > ?', 1.hour.ago).count },
                         :general_should_throttle?, 3.days.ago)
    create_user_throttle(:dmail, ->{ Danbooru.config.dmail_limit - Dmail.sent_by(id).where('created_at > ?', 1.hour.ago).count },
                         nil, nil)
    create_user_throttle(:dmail_minute, ->{ Danbooru.config.dmail_minute_limit - Dmail.sent_by(id).where('created_at > ?', 1.minute.ago).count },
                         nil, nil)

    def max_saved_searches
      if is_platinum?
        1_000
      else
        250
      end
    end

    def show_saved_searches?
      true
    end

    def can_comment_vote?
      CommentVote.where("user_id = ? and created_at > ?", id, 1.hour.ago).count < 10
    end

    def can_remove_from_pools?
      created_at <= 1.week.ago
    end

    def can_view_flagger?(flagger_id)
      is_moderator? || flagger_id == id
    end

    def can_view_flagger_on_post?(flag)
      (is_moderator? && flag.not_uploaded_by?(id)) || flag.creator_id == id
    end

    def can_upload?
      can_upload_with_reason == true
    end

    def can_upload_with_reason
      if can_upload_free?
        true
      elsif hourly_upload_limit <= 0
        :REJ_UPLOAD_HOURLY
      elsif is_admin?
        true # TODO: Remove this?
      elsif created_at > 1.week.ago
        :REJ_UPLOAD_NEWBIE
      elsif !is_platinum? && post_edit_limit <= 0
        :REJ_UPLOAD_EDIT
      elsif upload_limit <= 0
        :REJ_UPLOAD_LIMIT
      else
        true
      end
    end

    def upload_limited_reason
      User.upload_reason_string(can_upload_with_reason)
    end

    def hourly_upload_limit
      30 - Post.for_user(id).where("created_at >= ?", 1.hour.ago).count
    end
    memoize :hourly_upload_limit

    def upload_limit
        pieces = upload_limit_pieces

        base_upload_limit + (pieces[:approved] / 10) - (pieces[:deleted] / 4) - pieces[:pending]
    end
    memoize :upload_limit

    def upload_limit_pieces
      deleted_count = Post.deleted.for_user(id).count
      unapproved_count = Post.pending_or_flagged.for_user(id).count
      approved_count = Post.for_user(id).where('is_flagged = false AND is_deleted = false AND is_pending = false').count

      return {deleted: deleted_count, approved: approved_count, pending: unapproved_count}
    end
    memoize :upload_limit_pieces

    def post_upload_throttle
      return post_upload_limit if is_privileged_or_higher?
      [hourly_upload_limit, tag_edit_limit].min
    end
    memoize :post_upload_throttle

    def tag_query_limit
      40
    end

    def favorite_limit
      if is_platinum?
        40_000
      elsif is_privileged?
        20_000
      else
        10_000
      end
    end

    def api_regen_multiplier
      # regen this amount per second
      if is_platinum?
        4
      elsif is_privileged?
        2
      else
        1
      end
    end

    def api_burst_limit
      # can make this many api calls at once before being bound by
      # api_regen_multiplier refilling your pool
      if is_platinum?
        60
      elsif is_privileged?
        30
      else
        10
      end
    end

    def remaining_api_limit
      token_bucket.uncached_count
    end

    def statement_timeout
      if is_platinum?
        9_000
      elsif is_privileged?
        6_000
      else
        3_000
      end
    end
  end

  module ApiMethods
    # blacklist all attributes by default. whitelist only safe attributes.
    def hidden_attributes
      super + attributes.keys.map(&:to_sym)
    end

    def method_attributes
      list = super + [
        :id, :created_at, :name, :inviter_id, :level, :base_upload_limit,
        :post_upload_count, :post_update_count, :note_update_count,
        :is_banned, :can_approve_posts, :can_upload_free,
        :level_string,
      ]

      if id == CurrentUser.user.id
        list += BOOLEAN_ATTRIBUTES + [
          :updated_at, :email, :last_logged_in_at, :last_forum_read_at,
          :recent_tags, :comment_threshold, :default_image_size,
          :favorite_tags, :blacklisted_tags, :time_zone, :per_page,
          :custom_style, :favorite_count,
          :api_regen_multiplier, :api_burst_limit, :remaining_api_limit,
          :statement_timeout, :favorite_limit,
          :tag_query_limit, :can_comment_vote?, :can_remove_from_pools?,
          :is_comment_limited?, :can_comment?, :can_upload?, :max_saved_searches,
        ]
      end

      list
    end

    # extra attributes returned for /users/:id.json but not for /users.json.
    def full_attributes
      [
        :wiki_page_version_count, :artist_version_count,
        :artist_commentary_version_count, :pool_version_count,
        :forum_post_count, :comment_count,
        :appeal_count, :flag_count, :positive_feedback_count,
        :neutral_feedback_count, :negative_feedback_count, :upload_limit
      ]
    end

    def to_legacy_json
      return {
        "name" => name,
        "id" => id,
        "level" => level,
        "created_at" => created_at.strftime("%Y-%m-%d %H:%M")
      }.to_json
    end
  end

  module CountMethods
    def wiki_page_version_count
      user_status.wiki_edit_count
    end

    def post_update_count
      user_status.post_update_count
    end

    def post_upload_count
      user_status.post_count
    end

    def note_version_count
      user_status.note_count
    end

    def note_update_count
      note_version_count
    end

    def artist_version_count
      user_status.artist_edit_count
    end

    def artist_commentary_version_count
      ArtistCommentaryVersion.for_user(id).count
    end

    def pool_version_count
      user_status.pool_edit_count
    end

    def forum_post_count
      user_status.forum_post_count
    end

    def favorite_count
      user_status.favorite_count
    end

    def comment_count
      user_status.comment_count
    end

    def appeal_count
      PostAppeal.for_creator(id).count
    end

    def flag_count
      user_status.post_flag_count
    end

    def positive_feedback_count
      feedback.positive.count
    end

    def neutral_feedback_count
      feedback.neutral.count
    end

    def negative_feedback_count
      feedback.negative.count
    end

    def refresh_counts!
      self.class.without_timeout do
        UserStatus.where(user_id: id).update_all(
          post_count: Post.for_user(id).count,
          post_update_count: PostArchive.for_user(id).count,
          note_count: NoteVersion.where(updater_id: id).count
        )
      end
    end
  end

  module SearchMethods
    def named(name)
      where("lower(name) = ?", name)
    end

    def admins
      where("level = ?", Levels::ADMIN)
    end

    # UserDeletion#rename renames deleted users to `user_<1234>~`. Tildes
    # are appended if the username is taken.
    def deleted
      where("name ~ 'user_[0-9]+~*'")
    end

    def undeleted
      where("name !~ 'user_[0-9]+~*'")
    end

    def with_email(email)
      if email.blank?
        where("FALSE")
      else
        where("email = ?", email)
      end
    end

    def find_for_password_reset(name, email)
      if email.blank?
        where("FALSE")
      else
        where(["name = ? AND email = ?", name, email])
      end
    end

    def search(params)
      q = super
      q = q.joins(:user_status)

      params = params.dup
      params[:name_matches] = params.delete(:name) if params[:name].present?

      q = q.search_text_attribute(:name, params)
      q = q.attribute_matches(:level, params[:level])
      q = q.attribute_matches(:inviter_id, params[:inviter_id])
      # TODO: Doesn't support relation filtering using this method.
      # q = q.attribute_matches(:post_upload_count, params[:post_upload_count])
      # q = q.attribute_matches(:post_update_count, params[:post_update_count])
      # q = q.attribute_matches(:note_update_count, params[:note_update_count])
      # q = q.attribute_matches(:favorite_count, params[:favorite_count])

      if params[:name_matches].present?
        q = q.where_ilike(:name, normalize_name(params[:name_matches]))
      end

      if params[:inviter].present?
        q = q.where(inviter_id: search(params[:inviter]))
      end

      if params[:min_level].present?
        q = q.where("level >= ?", params[:min_level].to_i)
      end

      if params[:max_level].present?
        q = q.where("level <= ?", params[:max_level].to_i)
      end

      bitprefs_length = BOOLEAN_ATTRIBUTES.length
      bitprefs_include = nil
      bitprefs_exclude = nil

      [:can_approve_posts, :can_upload_free].each do |x|
        if params[x].present?
          attr_idx = BOOLEAN_ATTRIBUTES.index(x.to_s)
          if params[x].to_s.truthy?
            bitprefs_include ||= "0"*bitprefs_length
            bitprefs_include[attr_idx] = '1'
          elsif params[x].to_s.falsy?
            bitprefs_exclude ||= "0"*bitprefs_length
            bitprefs_exclude[attr_idx] = '1'
          end
        end
      end

      if bitprefs_include
        bitprefs_include.reverse!
        q = q.where("bit_prefs::bit(:len) & :bits::bit(:len) = :bits::bit(:len)",
                    {:len => bitprefs_length, :bits => bitprefs_include})
      end

      if bitprefs_exclude
        bitprefs_exclude.reverse!
        q = q.where("bit_prefs::bit(:len) & :bits::bit(:len) = 0::bit(:len)",
                    {:len => bitprefs_length, :bits => bitprefs_exclude})
      end

      if params[:current_user_first].to_s.truthy? && !CurrentUser.is_anonymous?
        q = q.order("id = #{CurrentUser.user.id.to_i} desc")
      end

      case params[:order]
      when "name"
        q = q.order("name")
      when "post_upload_count"
        q = q.order("user_statuses.post_count desc")
      when "note_count"
        q = q.order("user_statuses.note_count desc")
      when "post_update_count"
        q = q.order("user_statuses.post_update_count desc")
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  module StatisticsMethods
    def deletion_confidence(days = 30)
      Reports::UserPromotions.deletion_confidence_interval_for(self, days)
    end
  end

  concerning :SockPuppetMethods do
    def validate_sock_puppets
      if User.where(last_ip_addr: CurrentUser.ip_addr).where("created_at > ?", 1.day.ago).exists?
        errors.add(:last_ip_addr, "was used recently for another account and cannot be reused for another day")
      end
    end
  end

  include BanMethods
  include NameMethods
  include PasswordMethods
  include AuthenticationMethods
  include LevelMethods
  include EmailMethods
  include BlacklistMethods
  include ForumMethods
  include LimitMethods
  include ApiMethods
  include CountMethods
  extend SearchMethods
  extend ThrottleMethods
  include StatisticsMethods

  def as_current(&block)
    CurrentUser.as(self, &block)
  end

  def can_update?(object, foreign_key = :user_id)
    is_moderator? || is_admin? || object.__send__(foreign_key) == id
  end

  def dmail_count
    if has_mail?
      "(#{unread_dmail_count})"
    else
      ""
    end
  end

  def hide_favorites?
    !CurrentUser.is_admin? && enable_privacy_mode? && CurrentUser.user.id != id
  end

  def initialize_attributes
    self.last_ip_addr ||= CurrentUser.ip_addr
    self.enable_keyboard_navigation = true
    self.enable_auto_complete = true
  end

  def presenter
    @presenter ||= UserPresenter.new(self)
  end
end
