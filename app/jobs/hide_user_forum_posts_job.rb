# frozen_string_literal: true

class HideUserForumPostsJob < ApplicationJob
  sidekiq_options queue: "default", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(user_id, initiator_id)
    user = User.find(user_id)
    initiator = User.find(initiator_id) || User.system

    CurrentUser.scoped(initiator) do
      ForumTopic.without_timeout do
        ForumTopic.where(creator_id: user.id, is_hidden: false).find_each do |topic|
          topic.hide!
          topic.create_mod_action_for_hide
        end

        ForumPost
          .joins(:topic)
          .where(creator_id: user.id, is_hidden: false)
          .where.not(forum_topics: { creator_id: user.id })
          .find_each(&:hide!)
      end
    end
  end
end
