# frozen_string_literal: true

module Maintenance
  module User
    class ApiKeysController < ApplicationController
      before_action :requires_reauthentication
      before_action :member_only
      before_action :load_apikey
      respond_to :html

      def show
      end

      def update
        @api_key.regenerate!
        redirect_to(user_api_key_path(CurrentUser.user), notice: "API key regenerated")
      end

      def destroy
        @api_key.destroy
        redirect_to(CurrentUser.user)
      end

      private

      def load_apikey
        @api_key = CurrentUser.user.api_key || ApiKey.generate!(CurrentUser.user)
      end
    end
  end
end
