# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  helper MailerHelper
  default from: Danbooru.config.mail_from_addr, content_type: "text/html"
  layout "mailer"
  before_action :use_site_asset_host

  # Mail sent as another site (doc 38) links to that site, not the boot-time host
  def default_url_options
    options = super
    return options if CurrentSite.primary?
    options.merge(host: Danbooru.config.hostname)
  end

  def user_email(user)
    email_address_with_name(user.email, user.name)
  end

  protected

  def use_site_asset_host
    return if CurrentSite.primary? || config.asset_host.blank?
    config.asset_host = "https://#{Danbooru.config.hostname}"
  end

  # Guards against the mail gem raising on legacy malformed addresses:
  # https://github.com/e621ng/e621ng/issues/1712
  # EmailAddressValidator.valid? already returns false for blank, so this is a
  # strict superset of the former `user.email.blank?` check.
  def deliverable_email?(user)
    EmailAddressValidator.valid?(user.email)
  end
end
