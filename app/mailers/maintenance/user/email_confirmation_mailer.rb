# frozen_string_literal: true

module Maintenance
  module User
    class EmailConfirmationMailer < ActionMailer::Base
      helper ApplicationHelper
      helper UsersHelper
      default :from => Danbooru.config.mail_from_addr, :content_type => "text/html"

      def confirmation(user)
        @user = user
        mail(:to => @user.email, :subject => "#{Danbooru.config.app_name} account confirmation")
      end
    end
  end
end
