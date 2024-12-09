# frozen_string_literal: true

module Security
  class LockdownController < ApplicationController
    before_action :admin_only

    def index
    end

    def panic
      Security::Lockdown.uploads_disabled   = "1"
      Security::Lockdown.pools_disabled     = "1"
      Security::Lockdown.post_sets_disabled = "1"

      Security::Lockdown.comments_disabled  = "1"
      Security::Lockdown.forums_disabled    = "1"
      Security::Lockdown.blips_disabled     = "1"

      Security::Lockdown.aiburs_disabled    = "1"
      Security::Lockdown.favorites_disabled = "1"
      Security::Lockdown.votes_disabled     = "1"

      StaffAuditLog.log(:lockdown_panic, CurrentUser.user)
      redirect_to security_root_path
    end

    def enact
      params = lockdown_params

      Security::Lockdown.uploads_disabled = params[:uploads] if params[:uploads].present?
      Security::Lockdown.pools_disabled = params[:pools] if params[:pools].present?
      Security::Lockdown.post_sets_disabled = params[:post_sets] if params[:post_sets].present?

      Security::Lockdown.comments_disabled = params[:comments] if params[:comments].present?
      Security::Lockdown.forums_disabled = params[:forums] if params[:forums].present?
      Security::Lockdown.blips_disabled = params[:blips] if params[:blips].present?

      Security::Lockdown.aiburs_disabled = params[:aiburs] if params[:aiburs].present?
      Security::Lockdown.favorites_disabled = params[:favorites] if params[:favorites].present?
      Security::Lockdown.votes_disabled = params[:votes] if params[:votes].present?

      StaffAuditLog.log(:lockdown_uploads, CurrentUser.user, { params: params })
      redirect_to security_root_path
    end

    def uploads_min_level
      new_level = params[:uploads_min_level][:min_level].to_i
      raise ArgumentError, "#{new_level} is not valid" unless User.level_hash.values.include? new_level
      if new_level != Lockdown.uploads_min_level
        Security::Lockdown.uploads_min_level = new_level
        StaffAuditLog.log(:min_upload_level, CurrentUser.user, { level: new_level })
      end
      redirect_to security_root_path
    end

    def uploads_hide_pending
      duration = params[:uploads_hide_pending][:duration].to_f
      if duration >= 0 && duration != Security::Lockdown.hide_pending_posts_for
        Security::Lockdown.hide_pending_posts_for = duration
        StaffAuditLog.log(:hide_pending_posts_for, CurrentUser.user, { duration: duration })
      end
      redirect_to security_root_path
    end

    def lockdown_params
      permitted_params = %i[uploads pools post_sets comments forums blips aiburs favorites votes]

      params.fetch(:lockdown, {}).permit(permitted_params)
    end
  end
end
