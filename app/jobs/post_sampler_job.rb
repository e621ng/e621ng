# frozen_string_literal: true

class PostSamplerJob < ApplicationJob
  queue_as :video
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args, retry: 1

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    post = Post.find(id)
    ImageSampler.create_samples_for_post(post)
  end
end
