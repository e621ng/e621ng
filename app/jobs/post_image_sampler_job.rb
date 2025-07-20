# frozen_string_literal: true

class PostImageSamplerJob < ApplicationJob
  queue_as :thumb
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args, retry: 1

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    post = Post.find(id)
    ImageSampler.generate_post_images(post)
  end
end
