# frozen_string_literal: true

module Admin
  class VoteTrendsController < ApplicationController
    before_action :admin_only
    respond_to :html, :json
    
    def show
      params.permit(:user, :limit, :threshold, :duration, :id, :page, search: {})
      Rails.logger.debug "PARAMS: #{params.inspect}"
      puts "USER:: #{params[:user].to_i}"
      params.require(:user)

      @vote_trends = VoteManager::VoteAbuseMethods.vote_abuse_patterns(
        user: User.find(params[:user].to_i), 
        limit: params[:limit].to_i.presence, 
        threshold: params[:threshold].to_f.presence, 
        duration: params[:duration].presence
      )
      respond_with(@vote_trends) do |format|
        format.json { render json: @vote_trends.to_json }
      end
    end
  end
end