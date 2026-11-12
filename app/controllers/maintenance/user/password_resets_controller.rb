# frozen_string_literal: true

module Maintenance
  module User
    class PasswordResetsController < ApplicationController
      include RecoveryRequestGuard

      def new
        @nonce = UserPasswordResetNonce.new
      end

      def edit
        @nonce = find_nonce_from_params
      end

      def create
        email = params[:email].to_s.strip
        case throttle_recovery_request(email, new_maintenance_user_password_reset_path, "user.password_reset")
        when :rejected then return
        when :allowed
          sent = false
          ::User.with_email(email).each do |user|
            next if user.is_moderator?
            UserPasswordResetNonce.create(user_id: user.id)
            sent = true
          end
          DanbooruLogger.add_attributes("user.password_reset" => sent ? "sent" : "no_match")
        end
        redirect_to new_maintenance_user_password_reset_path, notice: RecoveryRequestGuard::GENERIC_NOTICE
      end

      def update
        @nonce = find_nonce_from_params
        return redirect_to new_maintenance_user_password_reset_path, notice: "Invalid reset token" if @nonce.nil?
        return redirect_to new_maintenance_user_password_reset_path, notice: "Reset expired" if @nonce.expired?

        if @nonce.reset_user!(params[:password], params[:password_confirm])
          DanbooruLogger.add_attributes("user.password_reset" => "completed")
          redirect_to new_maintenance_user_password_reset_path, notice: "Password reset"
        else
          DanbooruLogger.add_attributes("user.password_reset" => "invalid_password")
          # Re-render so the user can retry with the same token; uid/key come from the PATCH params.
          render :edit, status: 422
        end
      end

      private

      def find_nonce_from_params
        # Some translator software keeps appending extra text to the end of the UID.
        # Just strip the non-numeric characters, ex: "1739850关闭网页" -> "1739850"
        sanitized_uid = params[:uid].to_s.gsub(/[^\d]/, "")
        sanitized_uid = ParseValue.safe_id(sanitized_uid)
        return nil if sanitized_uid < 1

        if params[:uid].to_s != sanitized_uid.to_s
          Rails.logger.warn("Password reset UID sanitized: original='#{params[:uid]}', sanitized='#{sanitized_uid}', key_present=#{params[:key].present?}, user_agent='#{request.user_agent}'")
        end

        UserPasswordResetNonce.where("user_id = ? AND key = ?", sanitized_uid, params[:key]).first
      end
    end
  end
end
