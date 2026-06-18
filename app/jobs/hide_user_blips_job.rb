# frozen_string_literal: true

class HideUserBlipsJob < ApplicationJob
  queue_as :default
  sidekiq_options lock: :until_executing

  def perform(user_id, _initiator_id)
    user = User.find(user_id)
    CurrentUser.as_system do
      Blip.without_timeout do
        Blip.where(creator_id: user.id, is_deleted: false).find_each(&:delete!)
      end
    end
  end
end
