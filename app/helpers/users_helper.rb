# frozen_string_literal: true

module UsersHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate("#{user.id}", purpose, expires)
  end

  def email_domain_search(email)
    return unless email.include?("@")

    domain = email.split("@").last
    link_to "»", users_path(search: { email_matches: "*@#{domain}" })
  end
end
