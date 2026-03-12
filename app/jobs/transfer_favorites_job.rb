# frozen_string_literal: true

class TransferFavoritesJob < ApplicationJob
  queue_as :low_prio
  sidekiq_options lock: :until_executing

  def perform(*args)
    @post = Post.find_by(id: args[0])
    @user = User.find_by(id: args[1])
    return unless @post && @user

    CurrentUser.scoped(@user) do
      transfer_favorites!(@post)
    end
  end

  private

  def transfer_favorites!(post)
    parent = post.parent
    return false unless parent

    user_ids = post.fav_string.scan(/fav:(\d+)/).flatten.map(&:to_i)
    return false if user_ids.empty?

    # Prevent concurrent favorite operations
    transfer_flag = Post.flag_value_for("favorites_transfer_in_progress")
    post.update_columns(bit_flags: post.bit_flags | transfer_flag)
    parent.update_columns(bit_flags: parent.bit_flags | transfer_flag)

    begin
      existing_parent_user_ids = parent.fav_string.scan(/fav:(\d+)/).flatten.map(&:to_i)
      new_user_ids = user_ids - existing_parent_user_ids

      # 1. Delete all child favorites
      Favorite.without_timeout do
        Favorite.where(post_id: post.id).delete_all
      end

      # 2. Insert new parent favorites
      if new_user_ids.any?
        new_favorites = new_user_ids.map do |user_id|
          {
            post_id: parent.id,
            user_id: user_id,
            created_at: Time.current,
          }
        end
        Favorite.without_timeout do
          Favorite.insert_all(new_favorites)
        end
      end

      # 3. Update post and user data
      update_post_favorites_data(post, parent, user_ids, new_user_ids)
      update_user_favorite_counts(user_ids, new_user_ids)

      # 4. Safety check: Clean up any orphaned favorites that weren't caught by fav_string parsing
      cleanup_orphaned_child_favorites(post)

      # 5. Create post events
      PostEvent.add(post.id, CurrentUser.user, :favorites_moved, { parent_id: parent.id })
      PostEvent.add(parent.id, CurrentUser.user, :favorites_received, { child_id: post.id })

      # 6. Schedule index updates
      post.update_index(queue: :low_prio)
      parent.update_index(queue: :low_prio)
    ensure
      # Clean up flags even if post/parent was deleted during transfer
      begin
        post.reload
        parent.reload
        post.update_columns(bit_flags: post.bit_flags & ~transfer_flag)
        parent.update_columns(bit_flags: parent.bit_flags & ~transfer_flag)
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn("TransferFavoritesJob: Post or parent was deleted during transfer: #{e.message}")

        begin
          Post.where(id: post.id).update_all("bit_flags = bit_flags & ~#{transfer_flag}")
          Post.where(id: parent.id).update_all("bit_flags = bit_flags & ~#{transfer_flag}")
        rescue StandardError => cleanup_error
          Rails.logger.error("TransferFavoritesJob: Failed to cleanup flags after deletion: #{cleanup_error.message}")
        end
      rescue StandardError => e
        Rails.logger.error("TransferFavoritesJob: Failed to cleanup transfer flags: #{e.message}")

        begin
          Post.where(id: post.id).update_all("bit_flags = bit_flags & ~#{transfer_flag}")
          Post.where(id: parent.id).update_all("bit_flags = bit_flags & ~#{transfer_flag}")
        rescue StandardError => final_error
          Rails.logger.error("TransferFavoritesJob: Final cleanup attempt failed: #{final_error.message}")
        end
      end
    end

    true
  end

  # Update the fav_string and fav_count for both child and parent posts.
  def update_post_favorites_data(child_post, parent_post, _removed_user_ids, added_user_ids)
    # Remove all favorites from child post
    child_post.update_columns(
      fav_string: "",
      fav_count: 0,
      updated_at: Time.current,
    )

    # Add new favorites to parent post
    if added_user_ids.any?
      current_fav_string = parent_post.fav_string || ""
      current_fav_parts = current_fav_string.split
      new_fav_parts = added_user_ids.map { |user_id| "fav:#{user_id}" }
      all_fav_parts = (current_fav_parts + new_fav_parts).uniq

      parent_post.update_columns(
        fav_string: all_fav_parts.join(" "),
        fav_count: all_fav_parts.length,
        updated_at: Time.current,
      )
    end
  end

  # Update user favorite counts by calculating net changes.
  # Only adjusts counts for users with actual net gain/loss to avoid redundant operations.
  def update_user_favorite_counts(removed_user_ids, added_user_ids)
    users_with_net_loss = removed_user_ids - added_user_ids # parent already favorited: user loses a favorite
    users_with_net_gain = added_user_ids - removed_user_ids # child not favorited somehow, shouldn't happen

    if users_with_net_loss.any?
      UserStatus.without_timeout do
        users_with_net_loss.each_slice(5000) do |batch|
          UserStatus.where(user_id: batch).update_all("favorite_count = favorite_count - 1")
        end
      end
    end

    if users_with_net_gain.any?
      UserStatus.without_timeout do
        users_with_net_gain.each_slice(5000) do |batch|
          UserStatus.where(user_id: batch).update_all("favorite_count = favorite_count + 1")
        end
      end
    end
  end

  # Clean up any orphaned favorite records not captured by fav_string parsing.
  # Recalculates affected user favorite counts.
  def cleanup_orphaned_child_favorites(child_post)
    orphaned_favorites = Favorite.where(post_id: child_post.id)
    return unless orphaned_favorites.exists?
    orphaned_user_ids = orphaned_favorites.pluck(:user_id)

    Rails.logger.warn("TransferFavoritesJob: Found #{orphaned_favorites.count} orphaned favorites for post #{child_post.id} not in fav_string. User IDs: #{orphaned_user_ids}")

    Favorite.without_timeout do
      orphaned_favorites.delete_all
    end

    if orphaned_user_ids.any?
      Rails.logger.warn("TransferFavoritesJob: Recalculating favorite_count for #{orphaned_user_ids.count} users with orphaned favorites")
      UserStatus.without_timeout do
        UserStatus.where(user_id: orphaned_user_ids).update_all("favorite_count = (SELECT COUNT(*) FROM favorites WHERE favorites.user_id = user_statuses.user_id)")
      end
    end
  end
end
