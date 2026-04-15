# frozen_string_literal: true

module Maintenance
  module User
    class UserFeedbackMailer < ApplicationMailer
      helper DtextHelper

      def feedback_notice(user, feedback)
        return if user.email.blank?

        @user = user
        @feedback = feedback
        @is_ban = feedback.body.match(/^Banned (for |permanently)/)
        mail(
          to: user_email(@user),
          subject: "New #{Danbooru.config.app_name} Account Record",
        )
      end
    end
  end
end
