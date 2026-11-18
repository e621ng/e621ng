# frozen_string_literal: true

module Populate
  # Creates one topic. `count` is the number of posts including the opening post.
  class Forums < Base
    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      replies = count - 1
      log "* Creating a topic with #{replies} replies"

      users = options.fetch(:users, [])
      users = random_users if users.empty?

      category = ForumCategory.find_or_create_by!(name: "General") do |cat|
        cat.can_view = 0
      end

      CurrentUser.user = users.sample
      CurrentUser.ip_addr = LOCAL_IP
      topic = ForumTopic.create do |t|
        t.creator = CurrentUser.user
        t.creator_ip_addr = LOCAL_IP
        t.title = Faker::Lorem.sentence(word_count: 3, supplemental: true, random_words_to_add: 4)
        t.category = category
        t.original_post_attributes = {
          creator: CurrentUser.user,
          body: Faker::Lorem.paragraphs.join("\n\n"),
        }
      end

      log "  topic ##{topic.id} by #{CurrentUser.user.name}"
      log "  #{topic.errors.full_messages.join('; ')}" unless topic.valid?

      replies.times do
        CurrentUser.user = users.sample

        forum_post = ForumPost.create do |post|
          post.creator = CurrentUser.user
          post.topic_id = topic.id
          post.body = paragraph
        end

        log "  - #{CurrentUser.user.name} | forum post ##{forum_post.id}"
        log "    #{forum_post.errors.full_messages.join('; ')}" unless forum_post.valid?
      end

      topic
    end
  end
end
