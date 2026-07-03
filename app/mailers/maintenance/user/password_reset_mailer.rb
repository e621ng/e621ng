# frozen_string_literal: true

module Maintenance
  module User
    class PasswordResetMailer < ApplicationMailer
      def reset_request(user, nonce)
        return unless deliverable_email?(user)

        @user = user
        @nonce = nonce
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Password Reset",
        )
      end
    end
  end
end
