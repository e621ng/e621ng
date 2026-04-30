# frozen_string_literal: true

class Maintenance::User::PasswordResetMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def confirmation
    user = User.first
    nonce = UserPasswordResetNonce.create(user_id: user.id)
    Maintenance::User::PasswordResetMailer.reset_request(user, nonce)
  end
end
