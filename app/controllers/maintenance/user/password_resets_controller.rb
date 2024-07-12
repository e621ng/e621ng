# frozen_string_literal: true

module Maintenance
  module User
    class PasswordResetsController < ApplicationController
      def new
        @nonce = UserPasswordResetNonce.new
      end

      def create
        ::User.with_email(params[:email]).each do |user|
          next if user.is_moderator?
          UserPasswordResetNonce.create(user_id: user.id)
        end
        redirect_to new_maintenance_user_password_reset_path, :notice => "If your email was on file, an email has been sent your way. It should arrive within the next few minutes. Make sure to check your spam folder."
      end

      def edit
        @nonce = UserPasswordResetNonce.where('user_id = ? AND key = ?', params[:uid], params[:key]).first
      end

      def update
        @nonce = UserPasswordResetNonce.where('user_id = ? AND key = ?', params[:uid], params[:key]).first

        if @nonce
          if @nonce.expired?
            return redirect_to new_maintenance_user_password_reset_path, notice: "Reset expired"
          end
          if @nonce.reset_user!(params[:password], params[:password_confirm])
            @nonce.destroy
            redirect_to new_maintenance_user_password_reset_path, :notice => "Password reset"
          else
            redirect_to new_maintenance_user_password_reset_path, notice: "Passwords do not match"
          end
        else
          redirect_to new_maintenance_user_password_reset_path, :notice => "Invalid reset token"
        end
      end
    end
  end
end
