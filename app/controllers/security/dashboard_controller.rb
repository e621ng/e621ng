# frozen_string_literal: true

module Security
  class DashboardController < ApplicationController
    respond_to :html
    before_action :admin_only

    def index
    end
  end
end
