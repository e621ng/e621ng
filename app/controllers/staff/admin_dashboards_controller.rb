# frozen_string_literal: true

module Staff
  class AdminDashboardsController < ApplicationController
    before_action :admin_only

    def show
      @dashboard = AdminDashboard.new
    end
  end
end
