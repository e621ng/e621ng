# frozen_string_literal: true

class SessionLoader
  class AuthenticationFailure < StandardError; end
  class InsufficientScope < AuthenticationFailure; end
  class LevelBelowMinimum < AuthenticationFailure; end

  attr_reader :session, :cookies, :request, :params

  def initialize(request)
    @request = request
    @session = request.session
    @cookies = request.cookie_jar
    @params = begin
      request.parameters
    rescue ActionDispatch::Http::Parameters::ParseError
      {}
    end
    @remember_validator = ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
  end

  def load
    CurrentUser.user = User.anonymous
    CurrentUser.ip_addr = request.remote_ip

    if has_bearer_token?
      load_session_for_bearer
    elsif has_api_authentication?
      load_session_for_api
    elsif session[:user_id]
      load_session_user
    elsif has_remember_token?
      load_remember_token
    end

    CurrentUser.user.unban! if CurrentUser.user.ban_expired?
    if CurrentUser.user.is_restricted?
      recent_ban = CurrentUser.user.recent_ban
      if recent_ban.nil? || recent_ban.prevent_login?
        ban_message = "Account is banned: forever"
        if recent_ban&.expires_at.present?
          ban_message = "Account is suspended for another #{recent_ban.expire_days}"
        end
        raise AuthenticationFailure, ban_message
      end
    end
    update_user_login_tracking
    set_safe_mode
    refresh_old_remember_token
    refresh_unread_dmails
    DanbooruLogger.initialize(CurrentUser.user)
  end

  def has_api_authentication?
    has_bearer_token? || basic_auth_or_login_params?
  end

  # A forged cross-site form submission always carries an Origin header pointing at the attacker's
  # page, whereas non-browser API clients (curl, bots) send none. Mirror Rails' own same-origin
  # comparison so CSRF is only skipped for genuine first-party or non-browser requests.
  def same_origin_request?
    request.origin.nil? || request.origin == request.base_url
  end

  def has_bearer_token?
    bearer_token.present?
  end

  def bearer_token
    return @bearer_token if defined?(@bearer_token)

    auth = request.authorization.to_s
    @bearer_token = auth.start_with?("Bearer ") ? auth.split(" ", 2).last : nil
  end

  def has_remember_token?
    cookies.encrypted[:remember].present?
  end

  private

  def basic_auth_or_login_params?
    has_basic_authorization? || (params[:login].present? && params[:api_key].present?)
  end

  def has_basic_authorization?
    request.authorization.to_s.start_with?("Basic ")
  end

  def load_session_for_bearer
    token = Doorkeeper::AccessToken.by_token(bearer_token)
    raise AuthenticationFailure unless token&.accessible?

    unless token.scopes.exists?("full")
      raise InsufficientScope
    end

    user = User.find_by(id: token.resource_owner_id)
    raise AuthenticationFailure if user.nil?

    min_level = token.application&.minimum_user_level.to_i
    if min_level > 0 && user.level < min_level
      raise LevelBelowMinimum
    end

    # Doorkeeper::OAuth::Token.authenticate normally triggers this; bearer path bypasses it.
    token.revoke_previous_refresh_token! if Doorkeeper.config.refresh_token_enabled?

    CurrentUser.user = user
    CurrentUser.api_key = nil
    CurrentUser.oauth_token = token
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
      # Mirrors SessionCreator so OIDC auth_time reflects this restore.
      user.update_columns(last_logged_in_at: Time.now) unless user.is_restricted?
    rescue
      return
    end
  end

  def refresh_old_remember_token
    if cookies.encrypted[:remember] && !CurrentUser.user.is_logged_out?
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
    unless name.is_a?(String) && api_key.is_a?(String)
      raise AuthenticationFailure
    end
    unless name.dup.force_encoding("UTF-8").valid_encoding?
      Rails.logger.warn("Invalid UTF-8 in login parameter from #{request.remote_ip}")
      raise AuthenticationFailure
    end
    unless api_key.dup.force_encoding("UTF-8").valid_encoding?
      Rails.logger.warn("Invalid UTF-8 in api_key parameter from #{request.remote_ip}")
      raise AuthenticationFailure
    end

    auth_result = User.authenticate_api_key(name, api_key)
    raise AuthenticationFailure if auth_result.nil?
    user, api_key_record = auth_result
    CurrentUser.user = user
    CurrentUser.api_key = api_key_record
  rescue ActiveRecord::StatementInvalid => e
    if e.message.include?("invalid byte sequence") || e.message.include?("CharacterNotInRepertoire")
      Rails.logger.warn("Database encoding error during authentication from #{request.remote_ip}: #{e.message}")
      raise AuthenticationFailure
    else
      raise
    end
  end

  def load_session_user
    user = User.find_by(id: session[:user_id])
    raise AuthenticationFailure if user.nil?
    return if session[:ph] != user.password_token
    CurrentUser.user = user
    CurrentUser.api_key = nil
  end

  def update_user_login_tracking
    return if CurrentUser.user.is_logged_out?

    cache_key = if CurrentUser.api_key
                  "user_login_tracking:api_key:#{CurrentUser.api_key.id}"
                elsif CurrentUser.oauth_token
                  "user_login_tracking:oauth_token:#{CurrentUser.oauth_token.id}"
                else
                  "user_login_tracking:user:#{CurrentUser.id}"
                end
    return if Cache.redis.exists?(cache_key)

    Cache.redis.setex(cache_key, 60, "1")

    # last_logged_in_at feeds the OIDC auth_time claim; bearer use must not bump it.
    if CurrentUser.oauth_token.nil? &&
       (CurrentUser.last_logged_in_at.nil? || CurrentUser.last_logged_in_at <= 1.day.ago)
      CurrentUser.user.update_attribute(:last_logged_in_at, Time.now)
    end

    if CurrentUser.user.last_ip_addr != @request.remote_ip
      CurrentUser.user.update_attribute(:last_ip_addr, @request.remote_ip)
    end

    CurrentUser.api_key&.update_usage!(@request.remote_ip, @request.user_agent)
    CurrentUser.oauth_token&.update!(last_used_at: Time.current)
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
    return if CurrentUser.user.is_logged_out?
    return if cookies[:hide_dmail_notice].blank?

    if !CurrentUser.user.has_mail? && cookies[:hide_dmail_notice] == "1"
      cookies.delete(:hide_dmail_notice)
    end
  end
end
