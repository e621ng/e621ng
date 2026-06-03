# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper MailerHelper
  default from: Danbooru.config.mail_from_addr, content_type: "text/html"
  layout "mailer"

  def user_email(user)
    email_address_with_name(user.email, user.name)
  end

  protected

  # True when +user+ has an address the mail gem can turn into a recipient.
  #
  # Concrete mailers call this in place of the former `user.email.blank?` guard
  # so the action short-circuits for any undeliverable address, not just an
  # empty one. Legacy accounts may hold a malformed value (e.g.
  # "Email- Something-Weird-Comes@hotmail.com") that the mail gem cannot parse,
  # raising Mail::Field::IncompleteParseError and 500-ing the mailer. Bailing at
  # the action level (rather than only nil-ing the recipient) is required: a
  # Mail::Message with no destination raises "SMTP To address may not be blank"
  # at delivery time. EmailAddressValidator.valid? also returns false for a
  # blank value, so this stays a strict superset of the old guard. See issue
  # #1712.
  def deliverable_email?(user)
    EmailAddressValidator.valid?(user.email)
  end
end
