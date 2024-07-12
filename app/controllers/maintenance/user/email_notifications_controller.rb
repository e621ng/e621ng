# frozen_string_literal: true

module Maintenance
  module User
    class EmailNotificationsController < ApplicationController
      class VerificationError < Exception ; end

      before_action :validate_sig, :only => [:destroy]
      rescue_from VerificationError, :with => :render_403

      def show
      end

      def destroy
        @user = ::User.find(params[:user_id])
        @user.receive_email_notifications = false
        @user.save
      end

    private

      def render_403
        render plain: "", :status => 403
      end

      def validate_sig
        message = EmailLinkValidator.validate(params[:sig], :unsubscribe)
        if message.blank? || !message || message != params[:user_id].to_s
          raise VerificationError
        end
      end
    end
  end
end
