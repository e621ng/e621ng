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

  def simple_avatar(user, **options)
    return "" if user.nil?
    post_id = user.avatar_id
    deferred_post_ids.add(post_id) if post_id

    klass = options.delete(:class)
    named = options.delete(:named)
    tag.a href: user_path(user), class: "simple-avatar placeholder #{klass}", data: { id: post_id, name: user.name } do
      tag.span(class: "avatar-button") do
        concat tag.span(user.pretty_name, class: "avatar-name") if named
        concat tag.span(class: "avatar-image", data: { name: user.name[0].capitalize })
      end
    end
  end

  def profile_avatar(user, **options)
    return if user.nil?
    post_id = user.avatar_id
    deferred_post_ids.add(post_id) if post_id

    klass = options.delete(:class)

    render "/application/profile_avatar", user: user, post_id: post_id, klass: klass
  end

  def user_level_badge(user)
    return if user.nil?

    tag.span(class: "level-badge level-#{user.level_string.downcase}") do
      user.level_string.upcase
    end
  end

  def user_feedback_badge(user)
    return if user.nil?

    feedbacks = user.feedback_pieces
    deleted = CurrentUser.user.is_staff? ? feedbacks[:deleted] : 0
    active = feedbacks[:positive] + feedbacks[:neutral] + feedbacks[:negative]

    render "/application/feedback_badge", user: user, positive: feedbacks[:positive], neutral: feedbacks[:neutral], negative: feedbacks[:negative], deleted: deleted, active: active
  end
end
