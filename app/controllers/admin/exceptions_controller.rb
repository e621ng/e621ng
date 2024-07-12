# frozen_string_literal: true

module Admin
  class ExceptionsController < ApplicationController
    before_action :admin_only

    def index
      @exception_logs = ExceptionLog.search(search_params).paginate(params[:page], limit: 100)
    end

    def show
      if params[:id] =~ /\A\d+\z/
        @exception_log = ExceptionLog.find(params[:id])
      else
        @exception_log = ExceptionLog.find_by!(code: params[:id])
      end
    end
  end
end
