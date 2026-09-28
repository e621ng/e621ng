# frozen_string_literal: true

class TransferFavoritesJob < ApplicationJob
  sidekiq_options queue: "low_prio", lock: :until_executing, lock_ttl: 1.hour.to_i

  def perform(post_id, user_id)
    @post = Post.find_by(id: post_id)
    @user = User.find_by(id: user_id)
    return unless @post && @user

    CurrentUser.scoped(@user) do
      transfer_favorites!(@post)
    end
  end

  private

  def transfer_favorites!(post)
    parent = post.parent
    return false unless parent

    user_ids = Favorite.where(post_id: post.id).pluck(:user_id)
    return false if user_ids.empty?

    # Prevent concurrent favorite operations
    transfer_flag = Post.flag_value_for("favorites_transfer_in_progress")
    post.update_columns(bit_flags: post.bit_flags | transfer_flag)
    parent.update_columns(bit_flags: parent.bit_flags | transfer_flag)

    begin
      existing_parent_user_ids = Favorite.where(post_id: parent.id).pluck(:user_id)
      new_user_ids = user_ids - existing_parent_user_ids

      # Captured before the delete below, scoped to exactly the users who will get a
      # brand-new parent favorite - existing_parent_user_ids are never touched.
      child_folder_by_user = FavoriteFolderMembership
                             .where(post_id: post.id, user_id: new_user_ids)
                             .pluck(:user_id, :folder_id).to_h

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
        result = Favorite.without_timeout do
          Favorite.insert_all(new_favorites, returning: %i[id user_id created_at])
        end
        carry_over_folder_placements(parent, result, child_folder_by_user)
      end

      # 3. Update post and user data
      update_post_favorites_data(post, parent, user_ids, new_user_ids)
      update_user_favorite_counts(user_ids, new_user_ids)

      # 4. Safety check: clean up any favorites that landed on the child after the initial delete
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

  # Recompute fav_count for both child and parent from the favorites table.
  # The job reindexes both posts explicitly (step 6), so update_columns is enough.
  def update_post_favorites_data(child_post, parent_post, _removed_user_ids, added_user_ids)
    child_post.update_columns(fav_count: Favorite.where(post_id: child_post.id).count, updated_at: Time.current)

    if added_user_ids.any?
      parent_post.update_columns(fav_count: Favorite.where(post_id: parent_post.id).count, updated_at: Time.current)
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

  # Clean up any favorite records that raced in after the main delete_all.
  # Recalculates affected user favorite counts.
  def cleanup_orphaned_child_favorites(child_post)
    orphaned_favorites = Favorite.where(post_id: child_post.id)
    return unless orphaned_favorites.exists?
    orphaned_user_ids = orphaned_favorites.pluck(:user_id)

    Rails.logger.warn("TransferFavoritesJob: Found #{orphaned_favorites.count} orphaned favorites for post #{child_post.id} after transfer. User IDs: #{orphaned_user_ids}")

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

  # Best-effort: re-files newly-created parent favorites into whichever folder their
  # child favorite was already in. Never affects the favorite transfer itself - this
  # runs after the parent Favorite rows have already been inserted.
  def carry_over_folder_placements(parent, inserted_favorites, child_folder_by_user)
    return if child_folder_by_user.empty?

    live_folder_ids = FavoriteFolder.where(id: child_folder_by_user.values.uniq).pluck(:id).to_set
    new_memberships = inserted_favorites.to_a.filter_map do |row|
      folder_id = child_folder_by_user[row["user_id"]]
      next unless folder_id && live_folder_ids.include?(folder_id)
      membership_attrs(parent, row, folder_id)
    end
    return if new_memberships.empty?

    begin
      FavoriteFolderMembership.transaction(requires_new: true) do
        FavoriteFolderMembership.insert_all(new_memberships)
      end
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("TransferFavoritesJob: bulk membership carry-over failed for post #{parent.id}, retrying per folder: #{e.message}")
      insert_memberships_per_folder(new_memberships)
    end
  end

  def membership_attrs(parent, favorite_row, folder_id)
    {
      user_id: favorite_row["user_id"], folder_id: folder_id, favorite_id: favorite_row["id"], post_id: parent.id,
      favorite_created_at: favorite_row["created_at"], created_at: Time.current, updated_at: Time.current,
    }
  end

  # Only reached when the bulk attempt above raced against a folder deleted after the
  # live_folder_ids check. Each group gets its own savepoint (requires_new: true), so one
  # folder's constraint failure rolls back only that group's insert - not the whole
  # (possibly nested) surrounding transaction - and later groups can still write normally.
  def insert_memberships_per_folder(memberships)
    memberships.group_by { |m| m[:folder_id] }.each do |folder_id, group|
      FavoriteFolderMembership.transaction(requires_new: true) do
        FavoriteFolderMembership.insert_all(group)
      end
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("TransferFavoritesJob: could not carry over folder placement for folder #{folder_id}: #{e.message}")
    end
  end
end
