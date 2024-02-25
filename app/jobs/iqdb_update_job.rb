# frozen_string_literal: true

class IqdbUpdateJob < ApplicationJob
  queue_as :iqdb

  def perform(post_id)
    post = Post.find_by id: post_id
    return unless post

    IqdbProxy.update_post(post)
  end
end
