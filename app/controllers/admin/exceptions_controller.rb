module Admin
  class ExceptionsController < ApplicationController
    before_action :admin_only

    def index
      @exception_logs = ExceptionLog.order(id: :desc).paginate(params[:page], limit: 100)
    end

    def show
      @exception_log = ExceptionLog.find(params[:id])
    end
  end
end
