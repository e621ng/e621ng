# frozen_string_literal: true

module Maintenance
  module User
    class LoginReminderMailer < ApplicationMailer
      def notice(user)
        return unless deliverable_email?(user)

        @user = user
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Login Reminder",
        )
      end
    end
  end
end
