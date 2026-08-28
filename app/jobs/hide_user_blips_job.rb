# frozen_string_literal: true

class HideUserBlipsJob < ApplicationJob
  sidekiq_options queue: "default", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(user_id, initiator_id)
    user = User.find(user_id)
    initiator = User.find(initiator_id) || User.system

    CurrentUser.scoped(initiator) do
      Blip.without_timeout do
        Blip.where(creator_id: user.id, is_deleted: false).find_each(&:delete!)
      end
    end
  end
end
