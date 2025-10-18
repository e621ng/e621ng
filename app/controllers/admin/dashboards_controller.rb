# frozen_string_literal: true

module Admin
  class DashboardsController < ApplicationController
    before_action :admin_only

    def show
      @dashboard = AdminDashboard.new
      @tos_version = Setting.tos_version
    end

    def clear_cache
      Cache.delete("tos_content")
      flash[:notice] = "Terms of use cache cleared"
      redirect_to admin_dashboard_path
    end

    def bump_version
      new_version = Setting.tos_version.to_i + 1
      Setting.tos_version = new_version
      Cache.delete("tos_content")
      flash[:notice] = "Terms of use version bumped to #{new_version}"
      redirect_to admin_dashboard_path
    end
  end
end
