# frozen_string_literal: true

class Maintenance::User::PasswordResetMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def confirmation
    Maintenance::User::PasswordResetMailer.reset_request(User.first, UserPasswordResetNonce.new(user: User.first))
  end
end
