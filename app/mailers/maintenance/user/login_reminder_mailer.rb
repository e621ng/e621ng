# frozen_string_literal: true

module Maintenance
  module User
    class LoginReminderMailer < ApplicationMailer
      def notice(user)
        @user = user
        return if user.email.blank? # TODO: Ensure that UI also prevents this, rather than silently failing.
        mail(to: user.email, subject: "#{Danbooru.config.app_name} Login Reminder") do |format|
          format.html
        end
      end
    end
  end
end
