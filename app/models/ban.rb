class Ban < ApplicationRecord
  attr_accessor :is_permaban
  after_create :create_feedback
  after_create :update_user_on_create
  after_create :create_ban_mod_action
  after_destroy :update_user_on_destroy
  after_destroy :create_unban_mod_action
  belongs_to :user
  belongs_to :banner, :class_name => "User"
  validate :user_is_inferior
  validates :user_id, :reason, :duration, presence: true
  before_validation :initialize_banner_id, :on => :create
  before_validation :initialize_permaban, on: [:update, :create]

  scope :unexpired, -> { where("bans.expires_at > ? OR bans.expires_at IS NULL", Time.now) }
  scope :expired, -> { where("bans.expires_at IS NOT NULL").where("bans.expires_at <= ?", Time.now) }

  def self.is_banned?(user)
    exists?(["user_id = ? AND (expires_at > ? OR expires_at IS NULL)", user.id, Time.now])
  end

  def self.reason_matches(query)
    if query =~ /\*/
      where("lower(bans.reason) LIKE ?", query.mb_chars.downcase.to_escaped_for_sql_like)
    else
      where("bans.reason @@ plainto_tsquery(?)", query)
    end
  end

  def self.search(params)
    q = super

    if params[:banner_name]
      q = q.where("banner_id = (select _.id from users _ where lower(_.name) = ?)", params[:banner_name].mb_chars.downcase)
    end

    if params[:banner_id]
      q = q.where("banner_id = ?", params[:banner_id].to_i)
    end

    if params[:user_name]
      q = q.where("user_id = (select _.id from users _ where lower(_.name) = ?)", params[:user_name].mb_chars.downcase)
    end

    if params[:user_id]
      q = q.where("user_id = ?", params[:user_id].to_i)
    end

    q = q.attribute_matches(:reason, params[:reason_matches])

    q = q.expired if params[:expired].to_s.truthy?
    q = q.unexpired if params[:expired].to_s.falsy?

    case params[:order]
    when "expires_at_desc"
      q = q.order("bans.expires_at desc")
    else
      q = q.apply_default_order(params)
    end

    q
  end

  def self.prune!
    expired.includes(:user).find_each do |ban|
      ban.user.unban! if ban.user.ban_expired?
    end
  end

  def initialize_banner_id
    self.banner_id = CurrentUser.id if self.banner_id.blank?
  end

  def initialize_permaban
    if is_permaban == "1"
      self.duration = -1
    end
  end

  def user_is_inferior
    if user
      if user.is_admin?
        errors[:base] << "You can never ban an admin."
        false
      elsif user.is_moderator? && banner.is_admin?
        true
      elsif user.is_moderator?
        errors[:base] << "Only admins can ban moderators."
        false
      elsif banner.is_admin? || banner.is_moderator?
        true
      else
        errors[:base] << "No one else can ban."
        false
      end
    end
  end

  def update_user_on_create
    user.update_attributes(is_banned: true, level: 10)
  end

  def update_user_on_destroy
    user.update_attributes(is_banned: false, level: 20)
  end

  def user_name
    user ? user.name : nil
  end

  def user_name=(username)
    self.user_id = User.name_to_id(username)
  end

  def duration=(dur)
    dur = dur.to_i
    if dur < 0
      self.expires_at = nil
    else
      self.expires_at = dur.days.from_now
    end
    @duration = dur
  end

  def duration
    @duration
  end

  def humanized_duration
    return 'permanent' if expires_at == nil
    ApplicationController.helpers.distance_of_time_in_words(created_at, expires_at)
  end

  def humanized_expiration
    return 'never' if expires_at == nil
    ApplicationController.helpers.compact_time expires_at
  end

  def expire_days
    return 'never' if expires_at == nil
    ApplicationController.helpers.time_ago_in_words(expires_at)
  end

  def expired?
    expires_at != nil && expires_at < Time.now
  end

  def create_feedback
    user.feedback.create(category: "negative", body: "Banned for #{humanized_duration}: #{reason}")
  end

  def create_ban_mod_action
    ModAction.log(:user_ban, {duration: duration, reason: reason, user_id: user_id})
  end

  def create_unban_mod_action
    ModAction.log(:user_unban, {user_id: user_id})
  end
end
