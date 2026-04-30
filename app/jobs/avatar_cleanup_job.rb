# frozen_string_literal: true

class AvatarCleanupJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    return unless user.has_cropped_avatar?

    sm = Danbooru.config.storage_manager
    sm.delete_avatar(user_id, "jpg")
    sm.delete_avatar(user_id, "webp")

    flag = User.flag_value_for("has_cropped_avatar")
    user.update_columns(bit_prefs: user.bit_prefs & ~flag)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
