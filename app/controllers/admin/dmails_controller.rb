# frozen_string_literal: true

module Admin
  class DmailsController < ApplicationController
    respond_to :html, :json
    before_action :is_bd_staff_only

    def index
      @user = User.find(params[:user_id])
      @query = Dmail.where("owner_id = ?", @user.id).search(search_params).includes(:to, :from)
      @dmails = @query.paginate(params[:page], limit: params[:limit])

      respond_with @dmails.to_json
    end

    def show
      @user = User.find(params[:user_id])
      @dmail = Dmail.find(params[:id])
      respond_with(@dmail)
    end
  end
end
