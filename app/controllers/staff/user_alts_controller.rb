# frozen_string_literal: true

module Staff
  # Moderator-accessible alt-account finder. Unlike the admin-only IP tools, its
  # output never contains IP values — only scores and IP-derived evidence — so
  # it is gated at moderator rather than admin.
  class UserAltsController < ApplicationController
    before_action :moderator_only
    respond_to :html, :json

    def show
      @user = User.find(params[:user_id])
      @finder = UserAltFinder.new(@user)
      @candidates = @finder.candidates
      @chains = @finder.chains

      respond_to do |format|
        format.html
        format.json { render json: UserAltBlueprint.render_as_hash(@candidates) }
      end
    end
  end
end
