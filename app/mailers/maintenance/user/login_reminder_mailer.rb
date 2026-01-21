# frozen_string_literal: true

module Maintenance
  module User
    class LoginReminderMailer < ApplicationMailer
      def notice(user)
        @user = user
        return if user.email.blank?
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Login Reminder",
        )
      end
    end
  end
end
