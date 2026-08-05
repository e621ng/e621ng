# frozen_string_literal: true

module Maintenance
  module User
    class TotpMailer < ApplicationMailer
      def totp_enabled(user)
        return unless deliverable_email?(user)

        @user = user
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Two-Factor Authentication Enabled",
        )
      end

      def totp_disabled(user)
        return unless deliverable_email?(user)

        @user = user
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Two-Factor Authentication Disabled",
        )
      end

      def backup_code_used(user, remaining_count)
        return unless deliverable_email?(user)

        @user = user
        @remaining_count = remaining_count
        mail(
          to: user_email(@user),
          subject: "#{Danbooru.config.app_name} Backup Code Used",
        )
      end
    end
  end
end
