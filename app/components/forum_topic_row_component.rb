# frozen_string_literal: true

# A single topic in the /forums listings (doc 46).
# pinned: renders a sticky topic, with a pin marker in place of the unread dot.
class ForumTopicRowComponent < ViewComponent::Base
  include IconHelper

  with_collection_parameter :topic

  def initialize(topic:, pinned: false)
    super()
    @topic = topic
    @pinned = pinned
  end

  private

  attr_reader :topic, :pinned

  def unread?
    return @unread if defined?(@unread)
    @unread = CurrentUser.is_logged_in? && !topic.read_by?(CurrentUser.user)
  end

  def reply_count
    [topic.response_count - 1, 0].max
  end

  def row_classes
    classes = ["forum-topic-item"]
    classes << "pinned" if pinned
    classes << "unread" if unread?
    classes.join(" ")
  end
end
