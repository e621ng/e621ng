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
      # Locked fresh lookup, not parent.lock! on the passed-in object: blocks if delete!
      # holds this row, and returns nil (not an exception) if it already removed it.
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
      # delete_locked!'s level-then-id lock order should prevent this; retry is defense
      # in depth for any residual contention.
      retry if attempts < 3
      raise
    end
  end

  def self.delete_locked!(user:, folder:)
    FavoriteFolder.transaction do
      new_parent_id = folder.parent_id

      # Locks folder + its whole sibling group (one id-ordered query) before the child
      # group below - a consistent level-then-id lock order across concurrent deletes,
      # so two deletes can never form a lock cycle.
      sibling_group = FavoriteFolder.where(user_id: user.id, parent_id: new_parent_id).order(:id).lock.to_a
      raise Error, "Folder not found" unless sibling_group.any? { |f| f.id == folder.id } # deleted concurrently

      existing_sibling_names = sibling_group.reject { |f| f.id == folder.id }.map { |f| f.name.downcase }

      # Bare scopes, not folder.children/folder.favorites: loading those would cache
      # pre-promotion results and make destroy!'s restrict_with_exception check below see
      # stale, non-empty associations.
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
        # A new sibling can still be inserted between the check above and this update;
        # the partial unique indexes are the final guarantee.
        raise Error, "Cannot delete: a folder with the same name already exists at the destination level"
      rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
        # Last-resort translation so a raw AR/PG error never reaches the controller.
        raise Error, "Cannot delete this folder: it still has contents. Please try again."
      end
    end
  end
  private_class_method :delete_locked!

  # Move a folder to a new parent (or to root) - hierarchy only, never sibling order:
  # folders are always displayed lower(name), id, which this never touches.
  # @param user [User] The user performing the move
  # @param folder [FavoriteFolder] The folder being moved
  # @param destination_parent_id [Integer, nil] The new parent folder's id, or nil for root
  # @return [FavoriteFolder] The moved folder (unchanged, if the move was a no-op)
  # @raises [Error] Ownership, missing-destination, cycle, or sibling-name-collision errors
  def self.move_folder!(user:, folder:, destination_parent_id:)
    raise Error, "Access denied" unless folder.user_id == user.id

    attempts = 0
    begin
      attempts += 1
      move_folder_locked!(user: user, folder: folder, destination_parent_id: destination_parent_id)
    rescue ActiveRecord::Deadlocked
      # Defense in depth: the combined lock below prevents move-vs-move deadlocks, but a
      # cross-type conflict with a concurrent delete!/create! on a shared ancestor is
      # still theoretically possible if ids don't correlate with tree depth.
      retry if attempts < 3
      raise
    end
  end

  def self.move_folder_locked!(user:, folder:, destination_parent_id:)
    FavoriteFolder.transaction do
      # Source and destination locked together in one id-ordered query, not as two
      # sequential locks - otherwise two folders swapped concurrently (A into B while B
      # into A) could each hold one and wait on the other.
      ids = destination_parent_id ? [folder.id, destination_parent_id].uniq : [folder.id]
      locked = FavoriteFolder.where(id: ids).order(:id).lock.index_by(&:id)

      locked_source = locked[folder.id]
      raise Error, "Folder not found" if locked_source.nil? # deleted concurrently since this call started
      raise Error, "Access denied" unless locked_source.user_id == user.id

      # Wraps the rest instead of an early `return`/`break` (Rails/TransactionExitStatement
      # disallows exiting a transaction block that way). No-op if already at this parent.
      if locked_source.parent_id != destination_parent_id
        if destination_parent_id
          locked_destination = locked[destination_parent_id]
          raise Error, "Folder not found" if locked_destination.nil?
          raise Error, "Folder does not belong to you" if locked_destination.user_id != user.id
          reject_if_moving_into_own_descendant!(locked_destination, locked_source.id)
        end

        # Lock destination siblings in id order for a stable collision check, matching
        # delete!'s sibling-group locking; the unique index remains the final guarantee.
        # The old sibling group source is leaving isn't locked - nothing about leaving it
        # needs to change.
        destination_siblings = FavoriteFolder.where(user_id: user.id, parent_id: destination_parent_id).order(:id).lock.to_a
        existing_names = destination_siblings.reject { |f| f.id == locked_source.id }.map { |f| f.name.downcase }
        if existing_names.include?(locked_source.name.downcase)
          raise Error, "A folder with that name already exists at the destination level"
        end

        locked_source.parent_id = destination_parent_id
        raise Error, locked_source.errors.full_messages.join(", ") unless locked_source.save
      end

      locked_source
    end
  rescue ActiveRecord::RecordNotUnique
    # Final race-safe guarantee, same as create!/rename!/delete!.
    raise Error, "A folder with that name already exists at the destination level"
  end
  private_class_method :move_folder_locked!

  # Walks up from destination toward root, locking each ancestor as it goes, so a
  # concurrent reparent can't invalidate the chain mid-check.
  def self.reject_if_moving_into_own_descendant!(destination, source_id)
    node = destination
    while node
      raise Error, "Cannot move a folder into itself or one of its descendants" if node.id == source_id
      return if node.parent_id.nil?
      node = FavoriteFolder.lock.find_by(id: node.parent_id)
    end
  end
  private_class_method :reject_if_moving_into_own_descendant!

  # Move a favorited post to a destination folder (or back to root, i.e. unfiled).
  # @param user [User] The user performing the move
  # @param post [Post] The post whose favorite is being moved
  # @param destination_folder_id [Integer, nil] The destination folder's id, or nil/blank for root
  # @return [FavoriteFolder, nil] The destination folder, or nil when moved back to root
  # @raises [Error] When the post isn't favorited by the user, or the destination is invalid
  def self.move!(user:, post:, destination_folder_id:)
    Favorite.transaction do
      # Locked fresh lookup, not just the earlier read: a concurrent unfavorite/
      # TransferFavoritesJob can no longer delete this row out from under the upsert
      # below. Locked before the destination folder to preserve existing error precedence;
      # no other path locks Favorite then FavoriteFolder or vice versa, so this ordering
      # can't deadlock against create!/delete!.
      favorite = Favorite.lock.for_user(user.id).find_by(post_id: post.id)
      raise Error, "You have not favorited this post" if favorite.nil?

      if destination_folder_id.blank?
        # Root is not a physical folder - moving there removes the membership row.
        FavoriteFolderMembership.where(favorite_id: favorite.id).delete_all
        next nil
      end

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
