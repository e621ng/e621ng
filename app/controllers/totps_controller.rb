# frozen_string_literal: true

class TotpsController < ApplicationController
  before_action :member_only
  before_action :reject_api_key_auth
  before_action :reject_bearer_auth
  before_action :requires_reauthentication
  respond_to :html

  def show
    return redirect_to(new_totp_path) unless CurrentUser.user.totp_enabled?

    @user_totp = CurrentUser.user.totp
  end

  def new
    return redirect_to(totp_path) if CurrentUser.user.totp_enabled?

    session[:pending_totp_secret] = UserTotp.generate_secret
    build_pending_totp
  end

  def create
    if CurrentUser.user.totp_enabled? || session[:pending_totp_secret].blank?
      return redirect_to(new_totp_path)
    end

    build_pending_totp
    timestamp = @pending_totp.totp.verify(params.dig(:totp, :code).to_s.gsub(/\s/, ""), drift_behind: UserTotp::DRIFT, drift_ahead: UserTotp::DRIFT)
    if timestamp.nil?
      flash.now[:notice] = "Verification code was incorrect. Scan the same QR code and try again."
      render :new
      return
    end

    UserTotp.transaction do
      @user_totp = UserTotp.new(user: CurrentUser.user, secret: session[:pending_totp_secret])
      # Carrying the enrollment timestamp over prevents the code just used from being
      # replayed at the login challenge.
      @user_totp.last_used_step = timestamp
      @user_totp.save!
      @backup_codes = @user_totp.regenerate_backup_codes!
    end
    session.delete(:pending_totp_secret)
    refresh_session_password_token
    Maintenance::User::TotpMailer.totp_enabled(CurrentUser.user).deliver_now
    render :backup_codes
  end

  def destroy
    user_totp = CurrentUser.user.totp
    return redirect_to(new_totp_path) if user_totp.nil?

    case verify_code_with_rate_limit(user_totp)
    when :rate_limited
      redirect_to(new_totp_path, notice: "Too many attempts. Try again later.")
    when :incorrect
      redirect_to(new_totp_path, notice: "Verification code was incorrect.")
    else
      user_totp.destroy
      refresh_session_password_token
      Maintenance::User::TotpMailer.totp_disabled(CurrentUser.user).deliver_now
      redirect_to(settings_users_path, notice: "Two-factor authentication disabled")
    end
  end

  def regenerate_backup_codes
    @user_totp = CurrentUser.user.totp
    return redirect_to(new_totp_path) if @user_totp.nil?

    case verify_code_with_rate_limit(@user_totp)
    when :rate_limited
      redirect_to(new_totp_path, notice: "Too many attempts. Try again later.")
    when :incorrect
      redirect_to(new_totp_path, notice: "Verification code was incorrect.")
    else
      @backup_codes = @user_totp.regenerate_backup_codes!
      render :backup_codes
    end
  end

  private

  def build_pending_totp
    @pending_totp = UserTotp.new(user: CurrentUser.user, secret: session[:pending_totp_secret])
  end

  def refresh_session_password_token
    session[:ph] = CurrentUser.user.reload.password_token
  end

  # Disable and backup-code regeneration are code-guessing surfaces just like the login
  # challenge, so they share its per-user rate limit.
  def verify_code_with_rate_limit(user_totp)
    return :rate_limited if RateLimiter.check_limit("totp:#{CurrentUser.user.id}", 10, 1.hour)

    result = user_totp.verify_code!(params.dig(:totp, :code))
    return :ok if result

    RateLimiter.hit("totp:#{CurrentUser.user.id}", 1.hour)
    :incorrect
  end
end
