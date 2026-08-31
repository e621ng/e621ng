# frozen_string_literal: true

class PostImageSamplerJob < ApplicationJob
  # until_executing: a regeneration requested while one is running must not be
  # dropped; the lock only dedupes queued duplicates.
  sidekiq_options queue: "thumb", lock: :until_executing, lock_args_method: :lock_args, lock_ttl: 1.hour.to_i, retry: 1

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    post = Post.find(id)
    ImageSampler.generate_post_images(post)
  end
end
