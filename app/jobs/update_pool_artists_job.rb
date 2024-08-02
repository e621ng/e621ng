# frozen_string_literal: true

class UpdatePoolArtistsJob < ApplicationJob
  queue_as :tags
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args

  def self.lock_args(args)
    [args[0]]
  end

  def perform(*args)
    post = Post.find(args[0])

    post.update_pool_artists!
  end
end
