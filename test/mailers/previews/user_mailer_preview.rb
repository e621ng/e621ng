# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def dmail_notice
    UserMailer.dmail_notice(Dmail.first)
  end

  def forum_notice
    user = User.first
    forum_topic = ForumTopic.first
    forum_posts = forum_topic&.posts&.limit(5) || []
    UserMailer.forum_notice(user, forum_topic, forum_posts)
  end
end
