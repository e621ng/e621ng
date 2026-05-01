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

  def profile_avatar(user)
    return if user.nil?
    post_id = user.avatar_id
    deferred_post_ids.add(post_id) if post_id

    render "/application/profile_avatar", user: user, post_id: post_id
  end

  def user_level_badge(user)
    return if user.nil?

    tag.span(class: "level-badge level-#{user.level_string.downcase}") do
      (user.custom_title.presence || user.level_string).upcase
    end
  end

  def user_level_plain(user)
    return if user.nil?

    user.custom_title.presence || user.level_string
  end

  def user_bd_staff_badge(user)
    return unless user.is_bd_staff?

    tag.span(class: "level-badge") do
      "BD STAFF"
    end
  end
end
