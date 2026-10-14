# frozen_string_literal: true

class ArtistReindexJob < ApplicationJob
  include TransactionalEnqueue
  sidekiq_options queue: "low_prio", lock: :until_executed, lock_args_method: :lock_args, lock_ttl: 24.hours.to_i

  def self.lock_args(args)
    [args[0]]
  end

  def perform(artist_name)
    Post.without_timeout do
      Post.sql_raw_tag_match(artist_name).find_each { |post| post.update_index(queue: :low_prio) }
    end
  end
end
