# frozen_string_literal: true

class TermsOfUsesController < ApplicationController
  def accept
    if params[:state] == "accepted" && params[:age] == "on" && params[:terms] == "on"
      cookies.permanent.signed[:tos_accepted] = Setting.tos_version
    else
      notice = "You must accept the TOU and confirm that you are at least 18 years old to use this site"
    end

    redirect_back fallback_location: root_path, notice: notice
  end
end
