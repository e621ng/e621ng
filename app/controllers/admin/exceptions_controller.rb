# frozen_string_literal: true

module Admin
  class ExceptionsController < ApplicationController
    respond_to :json, :html
    before_action :admin_only

    def index
      @exception_logs = ExceptionLog.search(search_params).includes(:user).paginate(params[:page], limit: 100)
      respond_with(@exception_logs) do |format|
        format.json { render json: @exception_logs.to_json }
      end
    end

    def show
      if params[:id] =~ /\A\d+\z/
        @exception_log = ExceptionLog.includes(:user).find(params[:id])
      else
        @exception_log = ExceptionLog.includes(:user).find_by!(code: params[:id])
      end

      respond_with(@exception_log) do |format|
        format.json { render json: @exception_log }
      end
    end
  end
end
