# frozen_string_literal: true

class AvatarCropJob < ApplicationJob
  queue_as :default

  def perform(user_id, post_id, pos_x, pos_y, width)
    user = User.find(user_id)
    return unless user.avatar_id == post_id

    post = Post.find(post_id)
    ImageSampler.generate_avatar_crop(post, user_id, pos_x: pos_x, pos_y: pos_y, width: width)

    flag = User.flag_value_for("has_cropped_avatar")
    user.update_columns(bit_prefs: user.bit_prefs | flag)
    user.touch # otherwise, the old avatar may still be cached for a while
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
