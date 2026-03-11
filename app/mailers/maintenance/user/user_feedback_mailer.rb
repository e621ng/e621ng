# frozen_string_literal: true

module Maintenance
  module User
    class UserFeedbackMailer < ApplicationMailer
      helper DtextHelper

      def feedback_notice(user, feedback)
        @user = user
        @feedback = feedback
        mail(
          to: user_email(@user),
          subject: "New #{Danbooru.config.app_name} Account Record",
        )
      end
    end
  end
end
