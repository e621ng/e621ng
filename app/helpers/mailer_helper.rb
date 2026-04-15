# frozen_string_literal: true

module MailerHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate(user.id.to_s, purpose, expires)
  end
end
