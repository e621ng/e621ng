# frozen_string_literal: true

module MailerHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate(user.id.to_s, purpose, expires)
  end

  # Bound to the current key, so a new address or resend invalidates older links
  def email_activation_sig(user)
    EmailLinkValidator.generate([user.id, user.email_verification_key], :activate, 48.hours)
  end
end
