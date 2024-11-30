# frozen_string_literal: true

class ThumbnailJob < ApplicationJob
  queue_as :low_prio

  def perform(*args)
    @post = Post.find_by(id: args[0])
    return unless @post

    @post.regenerate_thumbnail!
  end
end
