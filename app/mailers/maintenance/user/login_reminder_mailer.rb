# frozen_string_literal: true

module Maintenance
  module User
    class LoginReminderMailer < ActionMailer::Base
      default :from => Danbooru.config.mail_from_addr, :content_type => "text/html"

      def notice(user)
        @user = user
        if user.email.present?
          mail(:to => user.email, :subject => "#{Danbooru.config.app_name} login reminder")
        end
      end
    end
  end
end
