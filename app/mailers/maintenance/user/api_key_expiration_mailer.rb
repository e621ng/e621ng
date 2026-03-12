# frozen_string_literal: true

module Maintenance
  module User
    class ApiKeyExpirationMailer < ApplicationMailer
      def expiration_notice(user, api_key)
        @user = user
        @api_key = api_key
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} API Key Expiration",
        )
      end
    end
  end
end
