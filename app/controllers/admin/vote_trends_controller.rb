# frozen_string_literal: true

module Admin
  class VoteTrendsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json
    def index
      permitted_params = params.permit(:user, :limit, :threshold, :duration, :vote_normality, :id, :page, :commit, search: {})
      vote_abuse_args = {}
      vote_abuse_args[:user] = User.find_by_name_or_id(permitted_params[:user]) if permitted_params[:user].present? # rubocop:disable Rails/DynamicFindBy
      vote_abuse_args[:vote_normality] = permitted_params[:vote_normality].to_i != 1
      vote_abuse_args[:limit] = permitted_params[:limit].to_i if permitted_params[:limit].present?
      vote_abuse_args[:threshold] = permitted_params[:threshold].to_f if permitted_params[:threshold].present?
      vote_abuse_args[:duration] = permitted_params[:duration] if permitted_params[:duration].present?

      if vote_abuse_args[:user].nil?
        Rails.logger.warn("Vote trends: No user found for '#{permitted_params[:user]}'")
        flash[:notice] = "No user found for '#{permitted_params[:user]}'"
        @vote_trends = []
        respond_with(@vote_trends) # show the page without any data
        return
      end

      Rails.logger.info("Vote trends: #{vote_abuse_args.inspect}")
      @vote_trends = VoteManager::VoteAbuseMethods.vote_abuse_patterns(**vote_abuse_args)
      respond_with(@vote_trends)
    end
  end
end
