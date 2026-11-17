# frozen_string_literal: true

class SessionCreator
  CHALLENGE_KEYS = %i[totp_user_id totp_expires_at totp_remember totp_url].freeze
  CHALLENGE_DURATION = 5.minutes
  # sid/sk name the UserSession row and prove the cookie holder owns it (doc 42).
  LOGIN_KEYS = %i[user_id ph sid sk last_authenticated_at].freeze
  REMEMBER_DURATION = 14.days

  attr_reader :request, :session, :cookies, :name, :password, :remember

  def self.remember_verifier
    ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
  end

  def self.set_remember_session(cookies, sid, secret)
    cookies.encrypted[:remember_session] = remember_cookie(remember_verifier.generate("#{sid}:#{secret}", purpose: "rbs", expires_in: REMEMBER_DURATION))
  end

  # Pre-doc-42 format, still issued during the transition so a rollback keeps users logged in.
  def self.set_legacy_remember(cookies, user)
    cookies.encrypted[:remember] = remember_cookie(remember_verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: REMEMBER_DURATION))
  end

  def self.remember_cookie(value)
    { value: value, expires: Time.now + REMEMBER_DURATION, httponly: true, same_site: :lax, secure: Rails.env.production? }
  end

  # Forgets the cookie login in this browser; revokes nothing.
  def self.clear_login(session, cookies)
    LOGIN_KEYS.each { |key| session.delete(key) }
    cookies.delete(:remember)
    cookies.delete(:remember_session)
  end

  def initialize(request, session, cookies, name, password, remember = false)
    @request = request
    @session = session
    @cookies = cookies
    @name = name
    @password = password
    @remember = remember
  end

  # :failed         — wrong credentials.
  # :totp_required  — password ok, but the account has 2FA; a short-lived challenge is
  #                   stashed in the session and nothing account-granting is set yet.
  # :succeeded      — logged in.
  def authenticate(url: nil)
    user = User.authenticate(name, password)
    return :failed unless user

    if user.totp_enabled?
      session[:totp_user_id] = user.id
      session[:totp_expires_at] = CHALLENGE_DURATION.from_now.utc.to_s
      session[:totp_remember] = remember
      session[:totp_url] = url
      return :totp_required
    end

    complete_login(user)
    :succeeded
  end

  def challenge_user
    return nil if session[:totp_user_id].blank?
    expires_at = Time.zone.parse(session[:totp_expires_at].to_s)

    # Clear if the challenge expired
    if expires_at.nil? || expires_at < Time.now.utc
      clear_challenge
      return nil
    end

    # Clear if the user no longer exists
    user = User.find_by(id: session[:totp_user_id])
    clear_challenge if user.nil?
    user
  end

  def complete_challenge(user)
    @remember = session[:totp_remember].to_s.truthy?
    url = session[:totp_url]
    clear_challenge
    complete_login(user)
    url
  end

  def clear_challenge
    CHALLENGE_KEYS.each { |key| session.delete(key) }
  end

  def complete_login(user)
    establish(user)
  end

  # Logs `user` in to this browser and returns its UserSession. Re-confirming the
  # password for the login already in the cookie keeps that row; anything else
  # starts from an empty session so a planted session id never survives a login.
  def establish(user)
    current = UserSession.authenticate(session[:sid], session[:sk]) if session[:sid].present?
    if current&.active? && current.user_id == user.id
      session[:last_authenticated_at] = Time.now.utc.to_s
      session[:ph] = user.password_token
      if remember && !current.remember
        current.remember!
        issue_remember_cookies(current, session[:sk])
      end
      CurrentUser.user_session = current
      return current
    end

    # Switching accounts ends the previous login.
    current&.revoke!("logout")
    # The one session key unrelated to the login; keep it so logging in does not
    # forget the pools the browser was just adding to.
    recent_pool_ids = session[:recent_pool_ids]
    request.reset_session
    session[:recent_pool_ids] = recent_pool_ids if recent_pool_ids.present?
    cookies.delete(:remember)
    cookies.delete(:remember_session)

    record, secret = UserSession.mint!(user, request: request, remember: remember)
    session[:user_id] = user.id
    session[:ph] = user.password_token
    session[:last_authenticated_at] = Time.now.utc.to_s
    session[:sid] = record.id
    session[:sk] = secret
    unless user.is_restricted?
      user.update_columns(last_ip_addr: request.remote_ip, last_logged_in_at: Time.now)
    end
    issue_remember_cookies(record, secret) if remember
    CurrentUser.user_session = record
    record
  end

  def clear_login
    self.class.clear_login(session, cookies)
  end

  private

  def issue_remember_cookies(record, secret)
    self.class.set_remember_session(cookies, record.id, secret)
    self.class.set_legacy_remember(cookies, record.user) if Danbooru.config.accept_legacy_sessions?
  end
end
