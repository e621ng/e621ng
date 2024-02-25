# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    if RateLimiter.check_limit("login:#{request.remote_ip}", 15, 12.hours)
      DanbooruLogger.add_attributes("user.login" => "rate_limited")
      return redirect_to(new_session_path, :notice => "Username/Password was incorrect")
    end
    session_creator = SessionCreator.new(session, cookies, params[:name], params[:password], request.remote_ip, params[:remember], request.ssl?)

    if session_creator.authenticate
      url = params[:url] if params[:url] && params[:url].start_with?("/") && !params[:url].start_with?("//")
      DanbooruLogger.add_attributes("user.login" => "success")
      redirect_to(url || posts_path, :notice => "You are now logged in")
    else
      RateLimiter.hit("login:#{request.remote_ip}", 6.hours)
      DanbooruLogger.add_attributes("user.login" => "fail")
      redirect_to(new_session_path, :notice => "Username/Password was incorrect")
    end
  end

  def destroy
    session.delete(:user_id)
    cookies.delete :remember
    redirect_to(posts_path, :notice => "You are now logged out")
  end
end
