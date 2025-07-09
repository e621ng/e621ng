# frozen_string_literal: true

module Admin
  class VoteTrendsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json
    def index
      params.permit(:user, :limit, :threshold, :duration, :vote_normality, :id, :page, search: {})
      # params.require(:user)
      if params[:user].blank? || !User.exists?(params[:user].to_i)
        # show the page without any data
        @vote_trends = []
        Rails.logger.debug "No user specified or user does not exist. Returning empty trends."
        respond_with(@vote_trends)
        return
      end

      vote_abuse_args = {
        user: User.find(params[:user].to_i),
        vote_normality: params[:vote_normality].to_i != 1,
      }
      vote_abuse_args[:limit] = params[:limit].to_i if params[:limit].present?
      vote_abuse_args[:threshold] = params[:threshold].to_f if params[:threshold].present?
      vote_abuse_args[:duration] = params[:duration] if params[:duration].present?

      @vote_trends = VoteManager::VoteAbuseMethods.vote_abuse_patterns(**vote_abuse_args)
      respond_with(@vote_trends)
    end
  end
end
