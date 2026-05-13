# frozen_string_literal: true

module Admin
  class AutomodDmailsController < ApplicationController
    respond_to :html, :json
    before_action :janitor_only

    def index
      @user = User.system
      @query = Dmail.where("owner_id = ?", @user.id).includes(:to, :from).search(search_params)
      @dmails = @query.paginate(params[:page], limit: params[:limit])

      respond_with @dmails.to_json
    end

    def show
      @user = User.system
      @dmail = find_system_dmail(params[:id])
      respond_with(@dmail)
    end

    def mark_as_read
      @dmail = find_system_dmail(params[:id])
      @dmail.mark_as_read!
      respond_to do |format|
        format.html { redirect_to(admin_automod_dmail_path(@dmail), notice: "Message marked as read") }
        format.json
      end
    end

    def mark_as_unread
      @dmail = find_system_dmail(params[:id])
      @dmail.mark_as_unread!
      respond_to do |format|
        format.html { redirect_to(admin_automod_dmail_path(@dmail), notice: "Message marked as unread") }
        format.json
      end
    end

    private

    def find_system_dmail(id)
      Dmail.where("owner_id = ?", User.system.id).includes(:to, :from).find(id)
    end
  end
end
