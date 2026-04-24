# frozen_string_literal: true

module Admin
  class AutomodDmailsController < ApplicationController
    respond_to :html, :json
    before_action :janitor_only

    def index
      @user = User.system
      @query = Dmail.where("owner_id = ?", @user.id).search(search_params).includes(:to, :from)
      @dmails = @query.paginate(params[:page], limit: params[:limit])

      respond_with @dmails.to_json
    end

    def show
      @user = User.system
      @dmail = Dmail.find(params[:id])
      respond_with(@dmail)
    end
  end
end
