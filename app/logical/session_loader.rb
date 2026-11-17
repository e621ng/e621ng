# frozen_string_literal: true

class SessionLoader
  class AuthenticationFailure < StandardError; end
  class InsufficientScope < AuthenticationFailure; end
  class LevelBelowMinimum < AuthenticationFailure; end
  # The cookie login itself is invalid; only this clears session/remember state (E6SEC-506).
  class SessionInvalid < AuthenticationFailure; end

  REAUTH_WINDOW = 1.hour

  attr_reader :session, :cookies, :request, :params

  # A password or TOTP change rotates the token, invalidating older cookie sessions;
  # the UserSession row behind the cookie must also still be live (doc 42).
  def self.session_token_valid?(session, user)
    session[:ph] == user.password_token && find_user_session(session, user).present?
  end

  # The row a cookie session names, :legacy for a pre-rollout cookie that may be
  # adopted, or nil when the login must not be honoured. Read-only: the Sidekiq
  # route constraint calls it outside any controller.
  def self.find_user_session(session, user)
    if session[:sid].present?
      record = UserSession.authenticate(session[:sid], session[:sk])
      record if record&.user_id == user.id && record.active?
    elsif Danbooru.config.accept_legacy_sessions? && !UserSession.legacy_blocked?(user, legacy_session_key(session))
      :legacy
    end
  end

  # Stable per pre-rollout login, so a copy of the same cookie resolves to the same key.
  def self.legacy_session_key(session)
    Digest::SHA256.hexdigest("#{session[:user_id]}:#{session[:ph]}:#{session[:last_authenticated_at].presence || 'remember'}")
  end

  # Hashes the verified payload: the old cookie was re-signed on every request,
  # so the signed string itself differs between copies.
  def self.legacy_remember_key(user_id, token)
    Digest::SHA256.hexdigest("#{user_id}:#{token}")
  end

  def self.recently_authenticated?(session)
    authenticated_at = Time.zone.parse(session[:last_authenticated_at].to_s)
    authenticated_at.present? && authenticated_at >= REAUTH_WINDOW.ago
  rescue ArgumentError
    false
  end

  def initialize(request)
    @request = request
    @session = request.session
    @cookies = request.cookie_jar
    @params = begin
      request.parameters
    rescue ActionDispatch::Http::Parameters::ParseError
      {}
    end
    @remember_validator = SessionCreator.remember_verifier
  end

  def load
    CurrentUser.user = User.anonymous
    CurrentUser.ip_addr = request.remote_ip

    if oauth_bearer_auth?
      @auth_source = :bearer
      load_session_for_bearer
    elsif has_api_authentication?
      @auth_source = :api
      load_session_for_api
    elsif session[:user_id]
      @auth_source = :session
      load_session_user
    elsif has_remember_token?
      load_remember_token
    end

    # Record the IP for everyone, including attempted logins from banned users.
    UserIpTracker.track!(CurrentUser.user, CurrentUser.ip_addr) if attributable_ip?

    CurrentUser.user.unban! if CurrentUser.user.ban_expired?
    if CurrentUser.user.is_restricted?
      recent_ban = CurrentUser.user.recent_ban
      if recent_ban.nil? || recent_ban.prevent_login?
        ban_message = "Account is banned: forever"
        if recent_ban&.expires_at.present?
          ban_message = "Account is suspended for another #{recent_ban.expire_days}"
        end
        # A banned API key must not log out the browser's cookie user.
        raise (cookie_auth? ? SessionInvalid : AuthenticationFailure), ban_message
      end
    end
    update_user_login_tracking
    touch_user_session
    set_safe_mode
    refresh_unread_dmails
    DanbooruLogger.initialize(CurrentUser.user)
  end

  def has_api_authentication?
    has_header_authentication? || has_login_param_authentication?
  end

  # Authentication carried in a request header (Authorization: Basic/Bearer). A cross-site
  # attacker cannot forge this: HTML forms can't set request headers, and a cross-origin
  # fetch() that sets Authorization triggers a CORS preflight the attacker's origin can't
  # satisfy. Header auth is therefore inherently immune to the CSRF forgery vector.
  def has_header_authentication?
    oauth_bearer_auth? || has_basic_authorization?
  end

  # Authentication carried in request params (login + api_key). This IS forgeable: a hidden
  # cross-site <form> can submit these fields, so it must be paired with a same-origin check.
  def has_login_param_authentication?
    params[:login].present? && params[:api_key].present?
  end

  # A forged cross-site form submission always carries an Origin header pointing at the attacker's
  # page, whereas non-browser API clients (curl, bots) send none. Mirror Rails' own same-origin
  # comparison so CSRF is only skipped for genuine first-party or non-browser requests.
  #
  # NOTE: an opaque-origin browser context (file://, sandboxed iframe, data: URL) sends the
  # literal header `Origin: null`, which arrives as the string "null" — not nil — so it is
  # correctly treated as NOT same-origin here.
  def same_origin_request?
    request.origin.nil? || request.origin == request.base_url
  end

  def has_bearer_token?
    bearer_token.present?
  end

  def oauth_bearer_auth?
    Danbooru.config.enable_oauth_provider? && has_bearer_token?
  end

  def bearer_token
    return @bearer_token if defined?(@bearer_token)

    auth = request.authorization.to_s
    @bearer_token = auth.start_with?("Bearer ") ? auth.split(" ", 2).last : nil
  end

  def has_remember_token?
    cookies.encrypted[:remember_session].present? || cookies.encrypted[:remember].present?
  end

  private

  def cookie_auth?
    @auth_source.in?(%i[session remember])
  end

  def has_basic_authorization?
    request.authorization.to_s.start_with?("Basic ")
  end

  # Navigations and subresource loads; fetch()/XHR send Sec-Fetch-Dest: empty.
  def browser_load?
    dest = request.headers["Sec-Fetch-Dest"]
    request.headers["Sec-Fetch-Mode"] == "navigate" || (dest.present? && dest != "empty")
  end

  def api_format?
    format = request.format
    format.present? && (format.json? || format.xml? || format.atom?)
  end

  # CORS allows any origin, so a cross-site page can send credentials from a visitor's
  # browser. That IP is the visitor's, not the credential owner's (E6SEC-519).
  def attributable_ip?
    return true unless @auth_source.in?(%i[api bearer])
    !request.headers["Sec-Fetch-Site"].in?(%w[cross-site same-site])
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
    if cookies.encrypted[:remember_session].present?
      restore_remembered_session
    elsif Danbooru.config.accept_legacy_sessions?
      restore_legacy_remember
    else
      cookies.delete(:remember)
    end
  end

  def restore_remembered_session
    sid, secret = verify_remember(cookies.encrypted[:remember_session], purpose: "rbs").to_s.split(":", 2)
    record = UserSession.authenticate(sid, secret)
    if record.nil? || !record.active?
      SessionCreator.clear_login(session, cookies)
      return
    end
    restore_login(record.user, record, secret)
  end

  def restore_legacy_remember
    pieces = verify_remember(cookies.encrypted[:remember], purpose: "rbr").to_s.split(":")
    return unless pieces.length == 2
    user = User.find_by(id: pieces[0].to_i)
    return if user.nil? || pieces[1].to_i != user.password_token

    key = self.class.legacy_remember_key(user.id, user.password_token)
    if UserSession.legacy_blocked?(user, key)
      cookies.delete(:remember)
      return
    end
    record, secret = UserSession.mint!(user, request: request, remember: true, legacy_key: key)
    @minted_this_request = true
    SessionCreator.set_remember_session(cookies, record.id, secret)
    restore_login(user, record, secret)
  end

  def restore_login(user, record, secret)
    CurrentUser.user = user
    CurrentUser.api_key = nil
    CurrentUser.user_session = record
    @user_session = record
    @auth_source = :remember
    session[:user_id] = user.id
    session[:ph] = user.password_token # This has been validated by the remember token
    session[:sid] = record.id
    session[:sk] = secret
    # Mirrors SessionCreator so OIDC auth_time reflects this restore.
    user.update_columns(last_logged_in_at: Time.now) unless user.is_restricted?
  end

  def verify_remember(value, purpose:)
    @remember_validator.verify(value, purpose: purpose)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  # Activity is recorded at most once per TOUCH_INTERVAL per session; revocation
  # is still read on every request. The remember cookie's browser expiry is
  # extended on the same cadence, with the same secret.
  def touch_user_session
    return if @user_session.nil?
    # The request that adopted a legacy cookie is not activity: the row must stay
    # untouched until the browser comes back, or every row minted by a parallel
    # first page load would be listed, counted and kept.
    return if @minted_this_request
    return unless Cache.redis.set("user_session_touch:#{@user_session.id}", "1", nx: true, ex: UserSession::TOUCH_INTERVAL.to_i)

    @user_session.touch_activity!(request)
    SessionCreator.set_remember_session(cookies, @user_session.id, session[:sk]) if @user_session.remember && session[:sk].present?
  end

  # Key/Basic credentials can be planted in a victim's browser through a link or embed (E6SEC-519).
  def load_session_for_api
    if browser_load? || !api_format?
      raise AuthenticationFailure, "API credentials are only accepted on .json, .xml or .atom requests from API clients or fetch()"
    end

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
    raise SessionInvalid if user.nil?

    found = self.class.find_user_session(session, user) if session[:ph] == user.password_token
    case found
    when UserSession
      @user_session = found
    when :legacy
      @user_session = adopt_legacy_session(user)
    else
      # Ended elsewhere (revoked, expired, credential change): forget it here so
      # the dead login is not looked up again on every request.
      SessionCreator.clear_login(session, cookies)
      return
    end
    CurrentUser.user = user
    CurrentUser.api_key = nil
    CurrentUser.user_session = @user_session
  end

  # First request from a browser logged in before user_sessions existed. The old
  # `remember` cookie is left in place (never refreshed) for rollback safety.
  def adopt_legacy_session(user)
    remembered = cookies.encrypted[:remember].present?
    record, secret = UserSession.mint!(user, request: request, remember: remembered, legacy_key: self.class.legacy_session_key(session))
    @minted_this_request = true
    session[:sid] = record.id
    session[:sk] = secret
    SessionCreator.set_remember_session(cookies, record.id, secret) if remembered
    record
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

    if attributable_ip? && CurrentUser.user.last_ip_addr != @request.remote_ip
      CurrentUser.user.update_attribute(:last_ip_addr, @request.remote_ip)
    end

    CurrentUser.api_key&.update_usage!(@request.remote_ip, @request.user_agent)
    CurrentUser.oauth_token&.update!(last_used_at: Time.current)
  end

  def set_safe_mode
    safe_mode = CurrentSite.safe_mode? || params[:safe_mode].to_s.truthy? || CurrentUser.user.enable_safe_mode?
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
    return unless cookie_auth?
    return if CurrentUser.user.is_logged_out?
    return if cookies[:hide_dmail_notice].blank?

    if !CurrentUser.user.has_mail? && cookies[:hide_dmail_notice] == "1"
      cookies.delete(:hide_dmail_notice)
    end
  end
end
