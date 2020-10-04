module Maintenance
  module User
    class EmailConfirmationMailer < ActionMailer::Base
      add_template_helper ApplicationHelper
      add_template_helper UsersHelper
      default :from => Danbooru.config.mail_from_addr, :content_type => "text/html"

      def confirmation(user)
        @user = user
        mail(:to => @user.email, :subject => "#{Danbooru.config.app_name} account confirmation")
      end
    end
  end
end
