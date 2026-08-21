# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    sparams = params.fetch(:session, {}).slice(:url, :name, :password, :remember)
    if login_limiter.throttled?
      DanbooruLogger.add_attributes("user.login" => "rate_limited")
      respond_to do |fmt|
        fmt.html { redirect_to(new_session_path, notice: "Too many login attempts. Try again later.") }
        fmt.json { render(json: { error: "Too many login attempts. Try again later." }, status: 429) }
      end
      return
    end
    session_creator = SessionCreator.new(request, session, cookies, sparams[:name], sparams[:password], sparams[:remember].to_s.truthy?)
    url = url_from(sparams[:url])

    case session_creator.authenticate(url: url)
    when :succeeded
      DanbooruLogger.add_attributes("user.login" => "success")
      respond_to do |fmt|
        fmt.html { redirect_to(url || posts_path) }
        fmt.json { render(json: { url: url || posts_path }) }
      end
    when :totp_required
      DanbooruLogger.add_attributes("user.login" => "totp_challenge")
      respond_to do |fmt|
        fmt.html { redirect_to(totp_session_path) }
        fmt.json { render(json: { error: "Two-factor authentication required. Log in through the website, or use an API key for scripts.", code: "totp_required", url: totp_session_path }, status: 401) }
      end
    else
      login_limiter.hit!
      DanbooruLogger.add_attributes("user.login" => "fail")
      respond_to do |fmt|
        fmt.html { redirect_back(fallback_location: new_session_path, allow_other_host: false, notice: "Username / Password was incorrect.") }
        fmt.json { render(json: { error: "Username / Password was incorrect." }, status: 401) }
      end
    end
  end

  def totp
    @user = session_creator.challenge_user
    redirect_to(new_session_path, notice: "Your login attempt has expired. Please log in again.") if @user.nil?
  end

  def verify_totp
    creator = session_creator
    user = creator.challenge_user
    if user.nil?
      respond_to do |fmt|
        fmt.html { redirect_to(new_session_path, notice: "Your login attempt has expired. Please log in again.") }
        fmt.json { render(json: { error: "Your login attempt has expired. Please log in again.", code: "challenge_expired" }, status: 401) }
      end
      return
    end

    # 2FA was removed mid-challenge (staff reset, or self-disable in another session).
    # Checked before the rate limiter: nothing to guess here.
    if user.totp.nil?
      url = creator.complete_challenge(user)
      DanbooruLogger.add_attributes("user.login" => "totp_removed")
      respond_to do |fmt|
        fmt.html { redirect_to(url || posts_path) }
        fmt.json { render(json: { url: url || posts_path }) }
      end
      return
    end

    totp_limiter = UserTotp.rate_limiter(user)
    if totp_limiter.throttled?
      DanbooruLogger.add_attributes("user.login" => "totp_rate_limited")
      respond_to do |fmt|
        fmt.html { redirect_to(totp_session_path, notice: "Too many attempts. Try again later.") }
        fmt.json { render(json: { error: "Too many attempts. Try again later." }, status: 429) }
      end
      return
    end

    result = user.totp.verify_code!(params.dig(:totp, :code))
    if result
      url = creator.complete_challenge(user)
      DanbooruLogger.add_attributes("user.login" => "totp_success")
      if result == :backup_code
        Maintenance::User::TotpMailer.backup_code_used(user, user.totp.backup_code_digests.size).deliver_now
      end
      respond_to do |fmt|
        fmt.html { redirect_to(url || posts_path) }
        fmt.json { render(json: { url: url || posts_path }) }
      end
    else
      totp_limiter.hit!
      DanbooruLogger.add_attributes("user.login" => "totp_fail")
      respond_to do |fmt|
        fmt.html do
          @user = user
          flash.now[:notice] = "Verification code was incorrect."
          render(:totp)
        end
        fmt.json { render(json: { error: "Verification code was incorrect." }, status: 401) }
      end
    end
  end

  def destroy
    session.delete(:user_id)
    cookies.delete(:remember)
    session.delete(:last_authenticated_at)
    session_creator.clear_challenge
    redirect_back_or_to(root_path, allow_other_host: false, notice: "You are now logged out")
  end

  def confirm_password
  end

  private

  # Failures are measured over a 6-hour window, but tripping the limit locks
  # the IP out for a full 12 hours. Only failed logins count; see #create.
  def login_limiter
    RateLimiter.new("login:#{request.remote_ip}", limit: 15, period: 6.hours, lockout: 12.hours)
  end

  def session_creator
    SessionCreator.new(request, session, cookies, nil, nil)
  end
end
