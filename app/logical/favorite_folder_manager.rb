# frozen_string_literal: true

class FavoriteFolderManager
  class Error < StandardError
  end

  # Create a folder for the given user.
  # @param user [User] The owner of the new folder
  # @param name [String] The folder's name
  # @param parent [FavoriteFolder, nil] The parent folder, or nil for a root-level folder
  # @raises [Error] When the parent doesn't belong to the user, no longer exists, or validation fails
  def self.create!(user:, name:, parent: nil)
    return create_root!(user: user, name: name) if parent.nil?

    FavoriteFolder.transaction do
      # A locked, fresh lookup by id (not parent.lock! on the passed-in object) so that
      # if delete!(parent) already committed and removed the row, this simply returns nil
      # instead of racing an insert into a folder that no longer exists. If delete! is
      # mid-transaction, this blocks until it finishes, serializing the two operations.
      locked_parent = FavoriteFolder.lock.find_by(id: parent.id)
      raise Error, "Folder not found" if locked_parent.nil?
      raise Error, "Folder does not belong to you" if locked_parent.user_id != user.id

      folder = user.favorite_folders.new(name: name, parent: locked_parent)
      raise Error, folder.errors.full_messages.join(", ") unless folder.save
      folder
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error, "A folder with that name already exists here"
  end

  def self.create_root!(user:, name:)
    folder = user.favorite_folders.new(name: name, parent: nil)
    raise Error, folder.errors.full_messages.join(", ") unless folder.save
    folder
  rescue ActiveRecord::RecordNotUnique
    raise Error, "A folder with that name already exists here"
  end
  private_class_method :create_root!

  # Rename a folder.
  # @param user [User] The user performing the rename
  # @param folder [FavoriteFolder] The folder to rename
  # @param name [String] The new name
  # @raises [Error] When the folder doesn't belong to the user or validation fails
  def self.rename!(user:, folder:, name:)
    raise Error, "Access denied" unless folder.user_id == user.id

    folder.name = name
    raise Error, folder.errors.full_messages.join(", ") unless folder.save
    folder
  rescue ActiveRecord::RecordNotUnique
    raise Error, "A folder with that name already exists here"
  end

  # Delete a folder. Its direct child folders and direct favorites are promoted to its
  # parent (or root); nothing is unfavorited. Transactional; blocked (not auto-renamed)
  # if promotion would collide with an existing sibling name at the destination level.
  # @param user [User] The user performing the deletion
  # @param folder [FavoriteFolder] The folder to delete
  # @raises [Error] When the folder doesn't belong to the user, or promotion would collide
  def self.delete!(user:, folder:)
    raise Error, "Access denied" unless folder.user_id == user.id

    attempts = 0
    begin
      attempts += 1
      delete_locked!(user: user, folder: folder)
    rescue ActiveRecord::Deadlocked
      # The locking in delete_locked! is deliberately ordered (own sibling-level group,
      # id-ascending, before the child-level group) specifically so concurrent deletes
      # can never form a lock cycle - see the comment there. This retry is defense-in-depth
      # against any residual contention that reasoning didn't foresee, not the primary
      # safety mechanism, so it stays small.
      retry if attempts < 3
      raise
    end
  end

  def self.delete_locked!(user:, folder:)
    FavoriteFolder.transaction do
      new_parent_id = folder.parent_id

      # Lock the folder being deleted together with ALL of its existing destination-level
      # siblings in one query, ordered by id. This is what makes concurrent deletes
      # deadlock-safe: two transactions deleting sibling folders A and B previously each
      # locked their own folder first (`folder.lock!`) and only then reached for the
      # other as a sibling - tx1 locks A then wants B, tx2 locks B then wants A, a classic
      # deadlock cycle. Locking the *entire* sibling group (which always includes `folder`
      # itself, since a folder shares its own parent_id with its siblings by definition)
      # in one ordered query means every transaction touching this group acquires locks
      # in the same order, so the second transaction simply blocks on the first row it
      # can't get instead of forming a cycle. Combined with locking the child-level group
      # strictly afterward (below) - never before - every transaction acquires locks in a
      # level-then-id order, which cannot cycle even across nested parent/child deletes.
      sibling_group = FavoriteFolder.where(user_id: user.id, parent_id: new_parent_id).order(:id).lock.to_a
      raise Error, "Folder not found" unless sibling_group.any? { |f| f.id == folder.id } # deleted concurrently since this call started

      existing_sibling_names = sibling_group.reject { |f| f.id == folder.id }.map { |f| f.name.downcase }

      # Deliberately independent relations, not folder.children/folder.favorites: loading
      # those association readers here would cache their pre-promotion result on this
      # `folder` instance, and folder.destroy! below runs a dependent: :restrict_with_exception
      # check against those same associations. If they were already loaded/cached from
      # before the update_all calls, that check could see stale (non-empty) rows and
      # falsely reject the destroy. Using bare scopes means the associations are never
      # populated, so destroy!'s restrict check queries fresh and correctly sees zero rows.
      child_folders_scope = FavoriteFolder.where(parent_id: folder.id)
      colliding_names = child_folders_scope.order(:id).lock.pluck(Arel.sql("lower(name)")) & existing_sibling_names
      if colliding_names.any?
        raise Error, "Cannot delete: a folder named '#{colliding_names.first}' already exists at the destination level"
      end

      begin
        child_folders_scope.update_all(parent_id: new_parent_id)
        # Membership rows are disposable organizational metadata, never the Favorite
        # itself: promoting to the parent updates folder_id in place; promoting to root
        # (new_parent_id.nil?) removes the row entirely, since root is "no membership
        # row," not a folder_id of nil (the column is NOT NULL - there is no root folder).
        if new_parent_id.nil?
          FavoriteFolderMembership.where(folder_id: folder.id).delete_all
        else
          FavoriteFolderMembership.where(folder_id: folder.id).update_all(folder_id: new_parent_id)
        end
        folder.destroy!
      rescue ActiveRecord::RecordNotUnique
        # A brand-new sibling could still be INSERTed by a concurrent request between our
        # check above and this update, since row locks can't lock rows that don't exist
        # yet - the partial unique indexes are the true final guarantee. Translate it to
        # the same collision error instead of leaking a raw DB exception.
        raise Error, "Cannot delete: a folder with the same name already exists at the destination level"
      rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
        # Should be unreachable now that create!/move! lock this folder's row before
        # attaching anything new to it - last-resort translation in case some future path
        # attaches content without going through that locking discipline, so a raw
        # ActiveRecord/PG error never reaches the controller. Unrelated DB errors are not
        # rescued here and still propagate.
        raise Error, "Cannot delete this folder: it still has contents. Please try again."
      end
    end
  end
  private_class_method :delete_locked!

  # Move a favorited post to a destination folder (or back to root, i.e. unfiled).
  # @param user [User] The user performing the move
  # @param post [Post] The post whose favorite is being moved
  # @param destination_folder_id [Integer, nil] The destination folder's id, or nil/blank for root
  # @return [FavoriteFolder, nil] The destination folder, or nil when moved back to root
  # @raises [Error] When the post isn't favorited by the user, or the destination is invalid
  def self.move!(user:, post:, destination_folder_id:)
    Favorite.transaction do
      # Locked, fresh lookup - not just the read used to decide whether to raise below -
      # so a concurrent unfavorite (FavoriteManager.remove!) or TransferFavoritesJob
      # (which deletes/replaces Favorite rows outside any lock this call previously took)
      # can no longer delete this row between the lookup and the upsert below. Either this
      # blocks until that concurrent transaction finishes (then re-reads a still-valid
      # row), or - if it already committed and removed the favorite - this simply finds no
      # row and raises the normal domain error, never a raw ActiveRecord::InvalidForeignKey
      # from upserting a membership against a favorite_id that no longer exists.
      #
      # Locked FIRST, before the destination folder below: this preserves the existing
      # error precedence (a missing favorite was already reported before an invalid
      # destination, even when both are true), and fixes the lock order for good - no
      # other code path ever locks a Favorite row and then wants a FavoriteFolder row (or
      # vice versa): create!/delete! only ever lock FavoriteFolder rows, and
      # FavoriteManager.remove!/TransferFavoritesJob only ever lock Post then Favorite
      # rows, never touching FavoriteFolder. With no other transaction ever holding one of
      # these two lock types while waiting on the other, this pair can't form a cycle
      # regardless of which order was picked - Favorite-then-Folder here is chosen only to
      # match the pre-existing validation order, not because the alternative would deadlock.
      favorite = Favorite.lock.for_user(user.id).find_by(post_id: post.id)
      raise Error, "You have not favorited this post" if favorite.nil?

      if destination_folder_id.blank?
        # Root (unfiled) is not a physical folder - "moved to root" means the membership
        # row is removed entirely, never a synthetic folder_id.
        FavoriteFolderMembership.where(favorite_id: favorite.id).delete_all
        next nil
      end

      # Same locked, fresh-lookup contract as create!'s parent lock: blocks if delete!
      # holds this folder's lock, and returns nil (not an exception) if it already
      # committed and removed the row.
      destination = FavoriteFolder.lock.find_by(id: destination_folder_id)
      raise Error, "Folder not found" if destination.nil?
      raise Error, "Folder does not belong to you" if destination.user_id != user.id

      FavoriteFolderMembership.upsert(
        {
          user_id: user.id,
          folder_id: destination.id,
          favorite_id: favorite.id,
          post_id: favorite.post_id,
          favorite_created_at: favorite.created_at,
        },
        unique_by: :index_favorite_folder_memberships_on_favorite_id,
      )
      destination
    end
  end
end
