# frozen_string_literal: true

class TermsOfUsesController < ApplicationController
  respond_to :html, only: [:show]
  respond_to :json, only: [:accept]
  before_action :admin_only, only: %i[clear_cache bump_version]

  def show
    @page_name = "e621:terms_of_service"
    @content = helpers.tos_content
    @version = Setting.tos_version
  end

  def accept
    if params[:state] == "accepted" && params[:age] == "on" && params[:terms] == "on"
      cookies.permanent.signed[:tos_accepted] = Setting.tos_version
      success = true
      message = nil
    else
      success = false
      message = "You must accept the TOU and confirm that you are at least 18 years old to use this site"
    end

    respond_to do |format|
      format.html do
        redirect_back fallback_location: root_path, notice: (message unless success)
      end
      format.json do
        if success
          render json: { success: true, version: Setting.tos_version }
        else
          render json: { success: false, message: message }
        end
      end
    end
  end

  def clear_cache
    Cache.delete("tos_content")
    flash[:notice] = "Terms of use cache cleared"
    redirect_to terms_of_use_path
  end

  def bump_version
    new_version = Setting.tos_version.to_i + 1
    Setting.tos_version = new_version
    Cache.delete("tos_content")
    flash[:notice] = "Terms of use version bumped to #{new_version}"
    redirect_to terms_of_use_path
  end
end
