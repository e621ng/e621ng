# frozen_string_literal: true

class AuthsController < ApplicationController
  respond_to :html

  def login
    respond_to do |format|
      format.html { render partial: "auths/login" }
    end
  end
end
