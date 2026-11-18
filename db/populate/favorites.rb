# frozen_string_literal: true

module Populate
  class Favorites < Base
    BATCH_SIZE = 500

    def call
      count = options.fetch(:count, 0)
      return unless count > 0
      log "* Creating #{count} favorites"

      users = options.fetch(:users, [])
      users = random_users(older_than: 0.days).to_a if users.empty?
      posts = random_posts(limit: [count, 1000].min).to_a # Limit posts to avoid too many random queries

      favorites_data = []
      seen = Set.new

      log "  Generating #{count} unique user-post combinations..."
      count.times do |index|
        user = users[index % users.size]
        post = posts.sample
        next unless seen.add?([user.id, post.id])

        favorites_data << { user_id: user.id, post_id: post.id, created_at: Time.current }
      end

      log "  Creating #{favorites_data.size} favorites in batches..."
      favorites_data.each_slice(BATCH_SIZE) do |batch|
        begin
          result = Favorite.insert_all(batch, returning: %i[id user_id post_id])
          log "    Created batch of #{result.rows.size} favorites"
        rescue StandardError => e
          log "    Error in batch creation: #{e.message}"
          # Fall back to individual creation with duplicate checking
          batch.each do |fav_attrs|
            user = User.find(fav_attrs[:user_id])
            post = Post.find(fav_attrs[:post_id])
            FavoriteManager.add!(user: user, post: post)
            log "    - ##{post.id} faved by #{user.name} (individual)"
          rescue StandardError => fav_error
            log "    - Error: #{fav_error.message}"
          end
          next # FavoriteManager keeps the counts itself
        end

        update_counts(batch)
      end

      log "  Completed creating favorites"
    end

    private

    def update_counts(batch)
      batch.pluck(:post_id).uniq.each do |post_id|
        Post.where(id: post_id).update_all(fav_count: Favorite.where(post_id: post_id).count, updated_at: Time.current)
      end

      batch.group_by { |fav| fav[:user_id] }.transform_values(&:size).each do |user_id, fav_count|
        UserStatus.where(user_id: user_id).update_all(["favorite_count = favorite_count + ?", fav_count])
      end
    end
  end
end
