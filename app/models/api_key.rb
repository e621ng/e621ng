# frozen_string_literal: true

class ApiKey < ApplicationRecord
  belongs_to :user
  validates :name, uniqueness: { scope: :user_id }, presence: true
  validates :key, uniqueness: true
  validate :validate_expiration_date, if: :expires_at?
  has_secure_token :key

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

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
      when /\A(id|name|created_at|updated_at|expires_at|last_used_at|uses)(?:_(asc|desc))?\z/i
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
    regenerate_key
    save!
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def active?
    !expired?
  end

  def update_usage!(ip_address = nil)
    update!(
      uses: uses + 1,
      last_used_at: Time.current,
      last_ip_address: ip_address,
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
end
