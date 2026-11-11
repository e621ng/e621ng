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

  # Runs the user's password validators without requiring the rest of the record
  # to be valid, so legacy accounts can still recover. Password errors are copied
  # onto this record for the edit form.
  def reset_user!(pass, confirm)
    pass = "" unless pass.is_a?(String)
    confirm = "" unless confirm.is_a?(String)

    user.password = pass
    user.password_confirmation = confirm
    user.validate
    # length/zxcvbn validators are skipped when password is blank on an existing record
    user.errors.add(:password, :blank) if pass.blank?

    password_errors = user.errors.where(:password) + user.errors.where(:password_confirmation)
    if password_errors.any?
      password_errors.each { |e| errors.add(:base, e.full_message) }
      return false
    end

    user.upgrade_password(pass)
    user.invalidate_password_reset_nonces
    true
  end

  def expired?
    created_at < 6.hours.ago
  end
end
