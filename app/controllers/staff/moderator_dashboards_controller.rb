# frozen_string_literal: true

module Staff
  class ModeratorDashboardsController < ApplicationController
    before_action :staff_only

    def show
      @dashboard = Moderator::Dashboard::Report.new(params[:min_date] || 2.days.ago.to_date, params[:max_level] || 20)
    end
  end
end
