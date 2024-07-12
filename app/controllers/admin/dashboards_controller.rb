# frozen_string_literal: true

module Admin
  class DashboardsController < ApplicationController
    before_action :admin_only

    def show
      @dashboard = AdminDashboard.new
    end
  end
end
