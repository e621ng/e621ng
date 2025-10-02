# frozen_string_literal: true

class TermsOfServicesController < ApplicationController
  respond_to :html, only: [:show]
  before_action :admin_only, only: %i[clear_cache bump_version]

  def show
    @page_name = "e621:terms_of_service"
    @content = helpers.tos_content
    @version = Setting.tos_version
  end

  def accept
    if params[:state] == "accepted" && params[:age] == "on" && params[:terms] == "on"
      cookies.permanent.signed[:tos_accepted] = Setting.tos_version
    else
      notice = "You must accept the TOS and confirm that you are at least 18 years old to use this site"
    end

    redirect_back fallback_location: root_path, notice: notice
  end

  def clear_cache
    Cache.delete("tos_content")
    flash[:notice] = "Terms of service cache cleared"
    redirect_to terms_of_service_path
  end

  def bump_version
    new_version = Setting.tos_version.to_i + 1
    Setting.tos_version = new_version
    Cache.delete("tos_content")
    flash[:notice] = "Terms of service version bumped to #{new_version}"
    redirect_to terms_of_service_path
  end
end
