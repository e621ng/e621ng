# frozen_string_literal: true

module Maintenance
  module User
    class PasswordResetMailer < ActionMailer::Base
      default :from => Danbooru.config.mail_from_addr, :content_type => "text/html"

      def reset_request(user, nonce)
        @user = user
        @nonce = nonce
        mail(:to => @user.email, :subject => "#{Danbooru.config.app_name} password reset")
      end
    end
  end
end
