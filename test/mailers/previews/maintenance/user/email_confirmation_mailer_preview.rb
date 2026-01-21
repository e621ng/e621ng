# frozen_string_literal: true

class Maintenance::User::EmailConfirmationMailerPreview < ActionMailer::Preview # rubocop:disable Style/ClassAndModuleChildren
  def confirmation
    Maintenance::User::EmailConfirmationMailer.confirmation(User.first)
  end
end
