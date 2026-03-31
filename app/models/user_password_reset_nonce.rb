# frozen_string_literal: true

class UserPasswordResetNonce < ApplicationRecord
  has_secure_token :key
  after_create :deliver_notice
  belongs_to :user

  def self.prune!
    where("created_at < ?", 2.days.ago).destroy_all
  end

  def deliver_notice
    if user.email.present?
      Maintenance::User::PasswordResetMailer.reset_request(user, self).deliver_now
    end
  end

  def reset_user!(pass, confirm)
    return false unless ActiveSupport::SecurityUtils.secure_compare(pass, confirm)
    user.upgrade_password(pass)
    true
  end

  def expired?
    created_at < 6.hours.ago
  end
end
