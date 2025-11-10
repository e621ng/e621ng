# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper MailerHelper
  default from: Danbooru.config.mail_from_addr, content_type: "text/html"
  layout "mailer"
end
