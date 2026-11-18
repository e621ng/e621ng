# frozen_string_literal: true

module Populate
  # Creates one pool holding `count` posts. Replaced by the export importer in doc 44 step 4.
  class Pools < Base
    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      log "* Generating pools"

      CurrentUser.user = User.find(1)
      posts = options.fetch(:posts, [])
      posts = random_posts(limit: count) if posts.empty?

      pool = Pool.create do |p|
        p.name = Faker::Lorem.sentence
        p.category = "collection"
        p.post_ids = posts.pluck(:id)
      end

      if pool.errors.empty?
        log "  pool ##{pool.id}"
      else
        log "    error: #{pool.errors.full_messages.join('; ')}"
      end

      pool
    end
  end
end
