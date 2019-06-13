module Maintenance
  module User
    class PasswordResetMailer < ActionMailer::Base
      def reset_request(user, nonce)
        @user = user
        @nonce = nonce
        mail(:to => @user.email, :subject => "#{Danbooru.config.app_name} password reset", :from => Danbooru.config.contact_email)
      end
    end
  end
end
