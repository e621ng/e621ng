module Maintenance
  module User
    class EmailConfirmationMailer < ActionMailer::Base
      add_template_helper ApplicationHelper
      add_template_helper UsersHelper

      def confirmation(user)
        @user = user
        mail(:to => @user.email, :subject => "#{Danbooru.config.app_name} account confirmation", :from => Danbooru.config.contact_email)
      end
    end
  end
end
