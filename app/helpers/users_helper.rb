# frozen_string_literal: true

module UsersHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate(user.id.to_s, purpose, expires)
  end

  def email_domain_search(email)
    return unless email.include?("@")

    domain = email.split("@").last
    link_to "»", users_path(search: { email_matches: "*@#{domain}" })
  end

  def user_level_badge(user)
    return if user.nil?

    tag.span(class: "level-badge #{user.level_css_class}") do
      user.level_string.upcase
    end
  end

  def user_custom_title_badge(user)
    return if user.nil?
    return if user.custom_title.blank?

    tag.span(class: "level-badge #{user.level_css_class}") do
      user.custom_title.upcase
    end
  end

  def user_level_plain(user)
    return if user.nil?

    user.custom_title.presence || user.level_string
  end

  def user_bd_staff_badge(user)
    return if user.nil?
    return unless user.is_bd_staff?

    tag.span(class: "level-badge") do
      "BD STAFF"
    end
  end
end
