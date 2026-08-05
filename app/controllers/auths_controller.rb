# frozen_string_literal: true

class AuthsController < ApplicationController
  respond_to :html

  def login
    respond_to do |format|
      format.html { render partial: "auths/login" }
    end
  end

  # Serves the 2FA challenge form for the login overlay. Only meaningful while a
  # challenge stashed by sessions#create is live; 404 otherwise so the overlay
  # falls back to the full-page flow.
  def totp
    challenge_user = SessionCreator.new(request, session, cookies, nil, nil).challenge_user
    respond_to do |format|
      format.html do
        if challenge_user.nil?
          head 404
        else
          render partial: "auths/totp"
        end
      end
    end
  end
end
