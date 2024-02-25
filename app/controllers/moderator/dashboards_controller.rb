# frozen_string_literal: true

module Moderator
  class DashboardsController < ApplicationController
    before_action :janitor_only

    def show
      @dashboard = Moderator::Dashboard::Report.new(params[:min_date] || 2.days.ago.to_date, params[:max_level] || 20)
    end
  end
end
