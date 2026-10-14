# frozen_string_literal: true

class SessionCreator
  CHALLENGE_KEYS = %i[totp_user_id totp_expires_at totp_remember totp_url].freeze
  CHALLENGE_DURATION = 5.minutes

  attr_reader :request, :session, :cookies, :name, :password, :remember

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
    session[:user_id] = user.id
    session[:last_authenticated_at] = Time.now.utc.to_s
    session[:ph] = user.password_token
    unless user.is_restricted?
      user.update_columns(last_ip_addr: request.remote_ip, last_logged_in_at: Time.now)
    end

    if remember
      verifier = ActiveSupport::MessageVerifier.new(Danbooru.config.remember_key, serializer: JSON, digest: "SHA256")
      cookies.encrypted[:remember] = { value: verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end
end
