# frozen_string_literal: true

module Maintenance
  module User
    class LoginRemindersController < ApplicationController
      include RecoveryRequestGuard

      def new
      end

      def create
        email = params.dig(:user, :email).to_s.strip
        case throttle_recovery_request(email, new_maintenance_user_login_reminder_path, "user.login_reminder")
        when :rejected then return
        when :allowed
          ::User.with_email(email).each do |user|
            next if user.is_moderator?
            LoginReminderMailer.notice(user).deliver_now
          end
        end
        redirect_to new_maintenance_user_login_reminder_path, notice: RecoveryRequestGuard::GENERIC_NOTICE
      end
    end
  end
end
