# frozen_string_literal: true

class ForumUpdater
  attr_reader :forum_topic, :forum_post, :expected_title

  def initialize(forum_topic, options = {})
    @forum_topic = forum_topic
    @forum_post = options[:forum_post]
    @expected_title = options[:expected_title]
    @skip_update = options[:skip_update]
  end

  def update(message, title_tag = nil)
    return if forum_topic.nil?

    CurrentUser.as_system do
      create_response(message)
      update_title(title_tag) if title_tag

      if forum_post
        update_post(message)
      end
    end
  end

  def create_response(body)
    forum_topic.posts.create(body: body, bypass_limits: true)
  end

  def update_title(title_tag)
    if forum_topic.title == expected_title
      forum_topic.update(:title => "[#{title_tag}] #{forum_topic.title}")
    end
  end

  def update_post(body)
    return if @skip_update
    forum_post.update(body: "#{forum_post.body}\n\nEDIT: #{body}")
  end
end
