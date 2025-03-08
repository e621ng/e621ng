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
    set_statement_timeout
    update_last_logged_in_at
    update_last_ip_addr
    set_time_zone
    set_safe_mode
    refresh_old_remember_token
    DanbooruLogger.initialize(CurrentUser.user)
  end

  def has_api_authentication?
    request.authorization.present? || params[:login].present? || params[:api_key].present?
  end

  def has_remember_token?
    cookies.encrypted[:remember].present?
  end

private

  def set_statement_timeout
    timeout = CurrentUser.user.statement_timeout
    ActiveRecord::Base.connection.execute("set statement_timeout = #{timeout}")
  end

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
    credentials = ::Base64.decode64(request.authorization.split(' ', 2).last || '')
    login, api_key = credentials.split(":", 2)
    authenticate_api_key(login, api_key)
  end

  def authenticate_api_key(name, api_key)
    user = User.authenticate_api_key(name, api_key)
    raise AuthenticationFailure if user.nil?
    CurrentUser.user = user
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
end
