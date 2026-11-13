# frozen_string_literal: true

class EmailsController < ApplicationController
  respond_to :html

  def resend_confirmation
    if IpBan.is_banned? CurrentUser.ip_addr
      redirect_to home_users_path, notice: "An error occurred trying to send an activation email"
      return
    end

    raise User::PrivilegeError.new("Must be logged in to resend verification email.") if CurrentUser.user.is_logged_out?
    raise User::PrivilegeError.new("Account already active.") if CurrentUser.user.is_verified?
    raise User::PrivilegeError.new('Cannot send confirmation because the email is not allowed.') if EmailBlacklist.is_banned?(CurrentUser.user.email)
    if RateLimiter.throttle!("emailconfirm:#{CurrentUser.user.id}", limit: 1, period: 12.hours)
      raise User::PrivilegeError.new("Confirmation email sent too recently. Please wait at least 12 hours between sends.")
    end

    # Rotate so earlier emails (and legacy id-only links) stop working
    CurrentUser.user.mark_unverified!
    Maintenance::User::EmailConfirmationMailer.confirmation(CurrentUser.user).deliver_now
    redirect_to home_users_path, notice: "Activation email resent"
  end

  def activate_user
    if IpBan.is_banned? CurrentUser.ip_addr
      redirect_to home_users_path, notice: 'An error occurred trying to activate your account'
      return
    end

    user, key = verify_get_user(:activate)
    raise User::PrivilegeError.new('Account cannot be activated because the email is not allowed.') if EmailBlacklist.is_banned?(user.email)
    raise User::PrivilegeError.new('Account already activated.') if user.is_verified?
    raise User::PrivilegeError.new("Invalid activation link.") unless user.email_verification_key_matches?(key)

    user.mark_verified!

    redirect_to home_users_path, notice: "Account activated"
  end

  private

  # Returns [user, key]; links must carry [user_id, email_verification_key]
  def verify_get_user(purpose)
    message = EmailLinkValidator.validate(params[:sig], purpose)
    raise User::PrivilegeError.new("Invalid activation link.") unless message.is_a?(Array) && message.size == 2
    user = User.find_by(id: message[0])
    raise User::PrivilegeError.new("Invalid activation link.") if user.nil?
    [user, message[1]]
  end
end
