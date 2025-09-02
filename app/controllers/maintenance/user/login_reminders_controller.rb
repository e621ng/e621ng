# frozen_string_literal: true

module Maintenance
  module User
    class LoginRemindersController < ApplicationController
      def new
      end

      def create
        ::User.with_email(params[:user][:email]).each do |user|
          next if user.is_moderator?
          LoginReminderMailer.notice(user).deliver_now
        end

        flash[:notice] = "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder"

        redirect_to new_maintenance_user_login_reminder_path
      end
    end
  end
end
