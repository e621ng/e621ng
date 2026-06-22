# frozen_string_literal: true

class HideUserCommentsJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  def perform(user_id, initiator_id)
    user = User.find(user_id)
    initiator = User.find(initiator_id) || User.system

    CurrentUser.scoped(initiator) do
      Comment.without_timeout do
        Comment.where(creator_id: user.id, is_hidden: false).find_each(&:hide!)
      end
    end
  end
end
