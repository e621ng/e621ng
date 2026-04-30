# frozen_string_literal: true

class AvatarCropJob < ApplicationJob
  queue_as :default

  def perform(user_id, post_id, x, y, w, h)
    user = User.find(user_id)
    return unless user.avatar_id == post_id

    post = Post.find(post_id)
    ImageSampler.generate_avatar_crop(post, user_id, x: x, y: y, w: w, h: h)

    flag = User.flag_value_for("has_cropped_avatar")
    user.update_columns(bit_prefs: user.bit_prefs | flag)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
