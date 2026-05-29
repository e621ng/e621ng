# frozen_string_literal: true

class AvatarCleanupJob < ApplicationJob
  queue_as :default

  def perform(user_id, force: false)
    user = User.find(user_id)

    # Don't perform cleanup if the user has a cropped avatar set.
    # Otherwise, we risk deleting the newly changed avatar if this job runs late.
    return if !force && user.avatar_id.present? && user.has_cropped_avatar?

    sm = Danbooru.config.storage_manager
    sm.delete_avatar(user_id, "jpg")
    sm.delete_avatar(user_id, "webp")

    if force
      flag = User.flag_value_for("has_cropped_avatar")
      user.update_columns(bit_prefs: user.bit_prefs & ~flag)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
