# frozen_string_literal: true

class ArtistReindexJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options lock: :until_executed, lock_args_method: :lock_args
  self.enqueue_after_transaction_commit = true

  def self.lock_args(args)
    [args[0]]
  end

  def perform(artist_name)
    Post.without_timeout do
      Post.sql_raw_tag_match(artist_name).find_each { |post| post.update_index(queue: :low_prio) }
    end
  end
end
