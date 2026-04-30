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

    if session_creator.authenticate
      @user = session.user
      url = sparams[:url] if sparams[:url]&.start_with?("/") && !sparams[:url].start_with?("//")
      DanbooruLogger.add_attributes("user.login" => "success")
      respond_to do |fmt|
        if @user.onboarding_completed?
          fmt.html { redirect_to(url || posts_path) }
        else
          fmt.html { redirect_to(onboarding_path) }
        end
        fmt.json { render(json: { url: url || posts_path }) }
      end
    else
      RateLimiter.hit("login:#{request.remote_ip}", 6.hours)
      DanbooruLogger.add_attributes("user.login" => "fail")
      respond_to do |fmt|
        fmt.html { redirect_back(fallback_location: new_session_path, notice: "Username / Password was incorrect.") }
        fmt.json { render(json: { error: "Username / Password was incorrect." }, status: 401) }
      end
    end
  end

  def destroy
    session.delete(:user_id)
    cookies.delete(:remember)
    session.delete(:last_authenticated_at)
    redirect_to(posts_path, notice: "You are now logged out")
  end

  def confirm_password
  end
end
