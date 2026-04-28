# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :user
  validates :name, uniqueness: { scope: :user_id }, presence: true
  validates :key, uniqueness: true
  validate :validate_expiration_date, if: :expires_at?
  validate :validate_api_key_limit, on: :create
  has_secure_token :key

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }
  scope :expiring_soon, -> { where(expires_at: Time.current..7.days.from_now, notified_at: nil).includes(:user) }

  module SearchMethods
    def visible(user)
      for_user(user.id)
    end

    def search(params)
      q = super

      q = q.includes(:user)
      q = q.attribute_matches(:name, params[:name_matches])
      q = q.where_user(:user_id, :user, params)

      if params[:is_expired].present?
        if params[:is_expired].to_s.truthy?
          q = q.expired
        elsif params[:is_expired].to_s.falsy?
          q = q.active
        end
      end

      case params[:order]
      when /\A(id|name|created_at|updated_at|expires_at|last_used_at)(?:_(asc|desc))?\z/i
        dir = $2 || :desc
        q = q.order($1 => dir).order(id: :desc)
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def self.generate!(user, name:, expires_at: nil)
    create!(user: user, name: name, expires_at: expires_at)
  end

  def regenerate!
    original_duration = calculate_duration
    self.created_at = Time.current
    self.expires_at = original_duration&.days&.from_now
    self.notified_at = nil # Reset notification flag for new expiration
    regenerate_key
    save!
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def update_usage!(ip_address = nil, user_agent = nil)
    update!(
      last_used_at: Time.current,
      last_ip_address: ip_address,
      last_user_agent: user_agent,
    )
  end

  def visible?(user)
    user_id == user.id
  end

  private

  def validate_expiration_date
    return if expires_at.blank?

    if expires_at <= Time.current
      errors.add(:expires_at, "must be in the future")
    end
  end

  def validate_api_key_limit
    if user.api_keys.size >= user.api_key_limit
      errors.add(:base, "API key limit reached")
    end
  end

  def calculate_duration
    return nil if expires_at.blank?
    ((expires_at - created_at) / 1.day).abs.ceil
  end
end
