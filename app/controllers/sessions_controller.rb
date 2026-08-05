# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    sparams = params.fetch(:session, {}).slice(:url, :name, :password, :remember)
    if RateLimiter.check_limit("login:#{request.remote_ip}", 15, 12.hours)
      DanbooruLogger.add_attributes("user.login" => "rate_limited")
      respond_to do |fmt|
        fmt.html { redirect_to(new_session_path, notice: "Too many login attempts. Try again later.") }
        fmt.json { render(json: { error: "Too many login attempts. Try again later." }, status: 429) }
      end
      return
    end
    session_creator = SessionCreator.new(request, session, cookies, sparams[:name], sparams[:password], sparams[:remember].to_s.truthy?)
    url = sparams[:url] if sparams[:url]&.start_with?("/") && !sparams[:url].start_with?("//")

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
      RateLimiter.hit("login:#{request.remote_ip}", 6.hours)
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

    if RateLimiter.check_limit("totp:#{user.id}", 10, 1.hour)
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
      RateLimiter.hit("totp:#{user.id}", 1.hour)
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

  def session_creator
    SessionCreator.new(request, session, cookies, nil, nil)
  end
end
