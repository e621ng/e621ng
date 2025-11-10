# frozen_string_literal: true

module Maintenance
  module User
    class EmailConfirmationMailer < ApplicationMailer
      def confirmation(user)
        @user = user
        mail(to: @user.email, subject: "#{Danbooru.config.app_name} Account Confirmation")
      end
    end
  end
end
