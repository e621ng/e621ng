# frozen_string_literal: true

class Maintenance::User::EmailConfirmationMailerPreview < ActionMailer::Preview
  def confirmation
    Maintenance::User::EmailConfirmationMailer.confirmation(User.first)
  end
end
