# frozen_string_literal: true

module Maintenance
  module User
    class PasswordResetsController < ApplicationController
      def new
        @nonce = UserPasswordResetNonce.new
      end

      def edit
        @nonce = find_nonce_from_params
      end

      def create
        ::User.with_email(params[:email]).each do |user|
          next if user.is_moderator?
          UserPasswordResetNonce.create(user_id: user.id)
        end
        redirect_to new_maintenance_user_password_reset_path, notice: "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder."
      end

      def update
        @nonce = find_nonce_from_params

        if @nonce
          if @nonce.expired?
            return redirect_to new_maintenance_user_password_reset_path, notice: "Reset expired"
          end
          if @nonce.reset_user!(params[:password], params[:password_confirm])
            @nonce.destroy
            redirect_to new_maintenance_user_password_reset_path, notice: "Password reset"
          else
            redirect_to new_maintenance_user_password_reset_path, notice: "Passwords do not match"
          end
        else
          redirect_to new_maintenance_user_password_reset_path, notice: "Invalid reset token"
        end
      end

      private

      def find_nonce_from_params
        # Some translator software keeps appending extra text to the end of the UID.
        # Just strip the non-numeric characters, ex: "1739850关闭网页" -> "1739850"
        sanitized_uid = params[:uid].to_s.gsub(/[^\d]/, "")
        return nil if sanitized_uid.blank?

        if params[:uid].to_s != sanitized_uid
          Rails.logger.warn("Password reset UID sanitized: original='#{params[:uid]}', sanitized='#{sanitized_uid}', key='#{params[:key]}', user_agent='#{request.user_agent}'")
        end

        UserPasswordResetNonce.where("user_id = ? AND key = ?", sanitized_uid, params[:key]).first
      end
    end
  end
end
