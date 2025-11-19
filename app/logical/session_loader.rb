# frozen_string_literal: true

class SessionLoader
  class AuthenticationFailure < Exception ; end

  attr_reader :session, :cookies, :request, :params

  def initialize(request)
    @request = request
    @session = request.session
    @cookies = request.cookie_jar
    @params = request.parameters
    @remember_validator = ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
  end

  def load
    CurrentUser.user = User.anonymous
    CurrentUser.ip_addr = request.remote_ip

    if has_api_authentication?
      load_session_for_api
    elsif session[:user_id]
      load_session_user
    elsif has_remember_token?
      load_remember_token
    end

    CurrentUser.user.unban! if CurrentUser.user.ban_expired?
    if CurrentUser.user.is_blocked?
      recent_ban = CurrentUser.user.recent_ban
      ban_message = "Account is banned: forever"
      if recent_ban && recent_ban.expires_at.present?
        ban_message = "Account is suspended for another #{recent_ban.expire_days}"
      end
      raise AuthenticationFailure.new(ban_message)
    end
    update_last_logged_in_at
    update_last_ip_addr
    set_time_zone
    set_safe_mode
    refresh_old_remember_token
    refresh_unread_dmails
    DanbooruLogger.initialize(CurrentUser.user)
  end

  def has_api_authentication?
    request.authorization.present? || params[:login].present? || params[:api_key].present?
  end

  def has_remember_token?
    cookies.encrypted[:remember].present?
  end

  private

  def load_remember_token
    begin
      message = @remember_validator.verify(cookies.encrypted[:remember], purpose: "rbr")
      return if message.nil?
      pieces = message.split(":")
      return unless pieces.length == 2
      user = User.find_by_id(pieces[0].to_i)
      return unless user
      return if pieces[1].to_i != user.password_token
      CurrentUser.user = user
      session[:user_id] = user.id
      session[:ph] = user.password_token # This has been validated by the remember token
    rescue
      return
    end
  end

  def refresh_old_remember_token
    if cookies.encrypted[:remember] && !CurrentUser.is_anonymous?
      cookies.encrypted[:remember] = {value: @remember_validator.generate("#{CurrentUser.id}:#{CurrentUser.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production?}
    end
  end

  def load_session_for_api
    if request.authorization
      authenticate_basic_auth
    elsif params[:login].present? && params[:api_key].present?
      authenticate_api_key(params[:login], params[:api_key])
    else
      raise AuthenticationFailure
    end
  end

  def authenticate_basic_auth
    auth_data = request.authorization.split(" ", 2).last || ""
    credentials = ::Base64.decode64(auth_data)

    # Validate inputs: PostgreSQL expects UTF-8
    unless credentials.dup.force_encoding("UTF-8").valid_encoding?
      Rails.logger.warn("Invalid UTF-8 in Basic Auth credentials from #{request.remote_ip}")
      raise AuthenticationFailure
    end

    login, api_key = credentials.split(":", 2)
    authenticate_api_key(login, api_key)
  rescue ArgumentError => e
    Rails.logger.warn("Invalid Base64 in Basic Auth from #{request.remote_ip}: #{e.message}")
    raise AuthenticationFailure
  end

  def authenticate_api_key(name, api_key)
    if name && !name.dup.force_encoding("UTF-8").valid_encoding?
      Rails.logger.warn("Invalid UTF-8 in login parameter from #{request.remote_ip}")
      raise AuthenticationFailure
    end
    if api_key && !api_key.dup.force_encoding("UTF-8").valid_encoding?
      Rails.logger.warn("Invalid UTF-8 in api_key parameter from #{request.remote_ip}")
      raise AuthenticationFailure
    end

    user = User.authenticate_api_key(name, api_key)
    raise AuthenticationFailure if user.nil?
    CurrentUser.user = user
  rescue ActiveRecord::StatementInvalid => e
    if e.message.include?("invalid byte sequence") || e.message.include?("CharacterNotInRepertoire")
      Rails.logger.warn("Database encoding error during authentication from #{request.remote_ip}: #{e.message}")
      raise AuthenticationFailure
    else
      raise
    end
  end

  def load_session_user
    user = User.find_by_id(session[:user_id])
    raise AuthenticationFailure if user.nil?
    return if session[:ph] != user.password_token
    CurrentUser.user = user
  end

  def update_last_logged_in_at
    return if CurrentUser.is_anonymous?
    return if CurrentUser.last_logged_in_at && CurrentUser.last_logged_in_at > 1.week.ago
    CurrentUser.user.update_attribute(:last_logged_in_at, Time.now)
  end

  def update_last_ip_addr
    return if CurrentUser.is_anonymous?
    return if CurrentUser.user.last_ip_addr == @request.remote_ip
    CurrentUser.user.update_attribute(:last_ip_addr, @request.remote_ip)
  end

  def set_time_zone
    time_zone = ActiveSupport::TimeZone[params[:time_zone].presence.to_s] || CurrentUser.user.time_zone
    Time.zone = time_zone
  end

  def set_safe_mode
    safe_mode = Danbooru.config.safe_mode? || params[:safe_mode].to_s.truthy? || CurrentUser.user.enable_safe_mode?
    CurrentUser.safe_mode = safe_mode
  end

  # This is here purely for the purpose of testing.
  def skip_cookies?
    false
  end

  # Resets the unread dmail cookie if it does not match the current user's dmail status.
  # This should normally happen when the user reads their last unread dmail.
  def refresh_unread_dmails
    return if skip_cookies?
    return if CurrentUser.is_anonymous?
    return if cookies[:hide_dmail_notice].blank?

    cookies.delete(:hide_dmail_notice) if cookies[:hide_dmail_notice] != CurrentUser.user.has_mail?.to_s
  end
end
