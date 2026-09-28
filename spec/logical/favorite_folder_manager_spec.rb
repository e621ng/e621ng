# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteFolderManager do
  include_context "as member"

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe ".create!" do
    it "creates a root-level folder" do
      folder = FavoriteFolderManager.create!(user: user, name: "Memes")
      expect(folder).to be_persisted
      expect(folder.parent_id).to be_nil
    end

    it "creates a folder nested under the given parent" do
      parent = create(:favorite_folder, user: user)
      folder = FavoriteFolderManager.create!(user: user, name: "Memes", parent: parent)
      expect(folder.parent_id).to eq(parent.id)
    end

    it "locks the parent row before creating a child (exercises the locked lookup path)" do
      parent = create(:favorite_folder, user: user)
      allow(FavoriteFolder).to receive(:lock).and_call_original
      FavoriteFolderManager.create!(user: user, name: "Memes", parent: parent)
      expect(FavoriteFolder).to have_received(:lock)
    end

    it "raises when the parent belongs to another user" do
      other_folder = create(:favorite_folder, user: other_user)
      expect { FavoriteFolderManager.create!(user: user, name: "Memes", parent: other_folder) }
        .to raise_error(FavoriteFolderManager::Error, /does not belong to you/)
    end

    it "raises cleanly (not a raw ActiveRecord error) when the parent no longer exists" do
      parent = create(:favorite_folder, user: user)
      parent.destroy!
      expect { FavoriteFolderManager.create!(user: user, name: "Memes", parent: parent) }
        .to raise_error(FavoriteFolderManager::Error, "Folder not found")
    end

    it "raises a friendly error on a case-insensitive name collision" do
      create(:favorite_folder, user: user, name: "Memes")
      expect { FavoriteFolderManager.create!(user: user, name: "memes") }
        .to raise_error(FavoriteFolderManager::Error, /already been taken/)
    end
  end

  describe ".rename!" do
    it "renames the folder" do
      folder = create(:favorite_folder, user: user, name: "Old")
      FavoriteFolderManager.rename!(user: user, folder: folder, name: "New")
      expect(folder.reload.name).to eq("New")
    end

    it "raises when the folder belongs to another user" do
      folder = create(:favorite_folder, user: other_user)
      expect { FavoriteFolderManager.rename!(user: user, folder: folder, name: "New") }
        .to raise_error(FavoriteFolderManager::Error, "Access denied")
    end

    it "raises a friendly error on a conflicting sibling rename" do
      create(:favorite_folder, user: user, name: "Taken")
      folder = create(:favorite_folder, user: user, name: "Original")
      expect { FavoriteFolderManager.rename!(user: user, folder: folder, name: "taken") }
        .to raise_error(FavoriteFolderManager::Error, /already been taken/)
    end
  end

  describe ".delete!" do
    it "deletes an empty folder" do
      folder = create(:favorite_folder, user: user)
      FavoriteFolderManager.delete!(user: user, folder: folder)
      expect(FavoriteFolder.exists?(folder.id)).to be false
    end

    it "promotes direct membership rows to the parent level and does not unfavorite the post" do
      parent = create(:favorite_folder, user: user, name: "parent")
      folder = create(:favorite_folder, user: user, name: "child", parent: parent)
      post = create(:post)
      favorite = Favorite.create!(user: user, post: post)
      membership = create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      FavoriteFolderManager.delete!(user: user, folder: folder)

      expect(Favorite.exists?(favorite.id)).to be true
      expect(membership.reload.folder_id).to eq(parent.id)
    end

    it "removes the membership row (moves the favorite to All Favorites) when the deleted folder was top-level" do
      folder = create(:favorite_folder, user: user)
      post = create(:post)
      favorite = Favorite.create!(user: user, post: post)
      membership = create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      FavoriteFolderManager.delete!(user: user, folder: folder)

      expect(Favorite.exists?(favorite.id)).to be true
      expect(FavoriteFolderMembership.exists?(membership.id)).to be false
    end

    it "promotes child folders to the parent level" do
      parent = create(:favorite_folder, user: user, name: "parent")
      folder = create(:favorite_folder, user: user, name: "child", parent: parent)
      grandchild = create(:favorite_folder, user: user, name: "grandchild", parent: folder)

      FavoriteFolderManager.delete!(user: user, folder: folder)

      expect(grandchild.reload.parent_id).to eq(parent.id)
    end

    it "succeeds when the folder has both child folders and direct memberships (association-cache regression case)" do
      parent = create(:favorite_folder, user: user, name: "parent")
      folder = create(:favorite_folder, user: user, name: "child", parent: parent)
      grandchild = create(:favorite_folder, user: user, name: "grandchild", parent: folder)
      post = create(:post)
      favorite = Favorite.create!(user: user, post: post)
      membership = create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      expect { FavoriteFolderManager.delete!(user: user, folder: folder) }.not_to raise_error

      expect(grandchild.reload.parent_id).to eq(parent.id)
      expect(membership.reload.folder_id).to eq(parent.id)
      expect(FavoriteFolder.exists?(folder.id)).to be false
    end

    it "does not change post fav_count, user favorite_count, or the Favorite's created_at" do
      folder = create(:favorite_folder, user: user)
      target_post = create(:post)
      FavoriteManager.add!(user: user, post: target_post)
      favorite = Favorite.for_user(user.id).find_by(post_id: target_post.id)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)
      favorite_count_before = user.reload.favorite_count
      created_at_before = favorite.created_at

      expect { FavoriteFolderManager.delete!(user: user, folder: folder) }
        .not_to(change { target_post.reload.fav_count })
      expect(user.reload.favorite_count).to eq(favorite_count_before)
      expect(favorite.reload.created_at).to eq(created_at_before)
    end

    it "blocks deletion when promoting a child folder would collide with an existing sibling name, and rolls back" do
      parent = create(:favorite_folder, user: user, name: "parent")
      create(:favorite_folder, user: user, name: "Memes", parent: parent)
      folder = create(:favorite_folder, user: user, name: "child", parent: parent)
      colliding_child = create(:favorite_folder, user: user, name: "memes", parent: folder)

      expect { FavoriteFolderManager.delete!(user: user, folder: folder) }
        .to raise_error(FavoriteFolderManager::Error, /already exists/)

      expect(FavoriteFolder.exists?(folder.id)).to be true
      expect(colliding_child.reload.parent_id).to eq(folder.id)
    end

    it "translates a residual DeleteRestrictionError into a clean Error" do
      folder = create(:favorite_folder, user: user)
      allow(folder).to receive(:destroy!).and_raise(ActiveRecord::DeleteRestrictionError.new("children"))

      expect { FavoriteFolderManager.delete!(user: user, folder: folder) }
        .to raise_error(FavoriteFolderManager::Error, /still has contents/)
    end

    it "raises when the folder belongs to another user" do
      folder = create(:favorite_folder, user: other_user)
      expect { FavoriteFolderManager.delete!(user: user, folder: folder) }
        .to raise_error(FavoriteFolderManager::Error, "Access denied")
    end

    describe "deadlock hardening" do
      it "retries and succeeds after a transient ActiveRecord::Deadlocked" do
        folder = create(:favorite_folder, user: user)
        call_count = 0
        allow(FavoriteFolderManager).to receive(:delete_locked!).and_wrap_original do |original, **kwargs|
          call_count += 1
          raise ActiveRecord::Deadlocked, "deadlock detected" if call_count < 3
          original.call(**kwargs)
        end

        expect { FavoriteFolderManager.delete!(user: user, folder: folder) }.not_to raise_error
        expect(call_count).to eq(3)
        expect(FavoriteFolder.exists?(folder.id)).to be false
      end

      it "re-raises after exhausting retries on a persistent deadlock" do
        folder = create(:favorite_folder, user: user)
        allow(FavoriteFolderManager).to receive(:delete_locked!).and_raise(ActiveRecord::Deadlocked, "deadlock detected")

        expect { FavoriteFolderManager.delete!(user: user, folder: folder) }.to raise_error(ActiveRecord::Deadlocked)
        expect(FavoriteFolder.exists?(folder.id)).to be true
      end

      it "locks the whole sibling group (which always includes the folder itself) in one id-ordered query" do
        parent = create(:favorite_folder, user: user, name: "parent")
        folder = create(:favorite_folder, user: user, name: "child", parent: parent)
        sibling = create(:favorite_folder, user: user, name: "sibling", parent: parent)

        allow(FavoriteFolder).to receive(:where).and_call_original
        FavoriteFolderManager.delete!(user: user, folder: folder)

        # The sibling-group lock query is scoped by (user_id, parent_id) - not by the
        # folder's own id - which is what makes it also cover `folder` and `sibling` in
        # one ordered SELECT ... FOR UPDATE, establishing the deterministic lock order
        # that prevents two concurrent sibling deletes from deadlocking against each other.
        expect(FavoriteFolder).to have_received(:where).with(user_id: user.id, parent_id: parent.id)
        expect(sibling.reload.parent_id).to eq(parent.id) # untouched: not part of this deletion's promotion
      end
    end
  end

  describe ".move!" do
    let(:post_record) { create(:post) }

    before { FavoriteManager.add!(user: user, post: post_record) }

    def membership_for(post)
      favorite = Favorite.for_user(user.id).find_by(post_id: post.id)
      FavoriteFolderMembership.find_by(favorite_id: favorite.id)
    end

    it "moves a favorite from root into a folder, creating a membership row" do
      folder = create(:favorite_folder, user: user)
      destination = FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id)
      expect(destination).to eq(folder)
      membership = membership_for(post_record)
      expect(membership.folder_id).to eq(folder.id)
      expect(membership.post_id).to eq(post_record.id)
    end

    it "stamps favorite_created_at from the Favorite's own created_at, not the move time" do
      folder = create(:favorite_folder, user: user)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id)
      expect(membership_for(post_record).favorite_created_at).to eq(favorite.created_at)
    end

    it "moves a favorite from a folder into a child folder (updates the existing membership row, doesn't duplicate it)" do
      parent = create(:favorite_folder, user: user, name: "parent")
      child = create(:favorite_folder, user: user, name: "child", parent: parent)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      create(:favorite_folder_membership, user: user, folder: parent, favorite: favorite)

      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: child.id)

      expect(FavoriteFolderMembership.where(favorite_id: favorite.id).count).to eq(1)
      expect(membership_for(post_record).folder_id).to eq(child.id)
    end

    it "moves a favorite up to the parent (simulating Go Up)" do
      grandparent = create(:favorite_folder, user: user, name: "a")
      parent = create(:favorite_folder, user: user, name: "b", parent: grandparent)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      create(:favorite_folder_membership, user: user, folder: parent, favorite: favorite)

      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: parent.parent_id)
      expect(membership_for(post_record).folder_id).to eq(grandparent.id)
    end

    it "removes the membership row (returns to All Favorites) from a top-level folder (simulating Go Up to root)" do
      folder = create(:favorite_folder, user: user)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      destination = FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.parent_id)
      expect(destination).to be_nil
      expect(Favorite.exists?(favorite.id)).to be true
      expect(membership_for(post_record)).to be_nil
    end

    it "locks the destination folder before moving (exercises the locked lookup path)" do
      folder = create(:favorite_folder, user: user)
      allow(FavoriteFolder).to receive(:lock).and_call_original
      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id)
      expect(FavoriteFolder).to have_received(:lock)
    end

    it "locks the favorite row before using it (exercises the locked lookup path, not a stale pre-fetched reference)" do
      folder = create(:favorite_folder, user: user)
      allow(Favorite).to receive(:lock).and_call_original
      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id)
      expect(Favorite).to have_received(:lock)
    end

    it "raises the normal domain error, not a raw DB exception, when the favorite was already deleted before move! could lock it - the race a concurrent unfavorite (FavoriteManager.remove!) or TransferFavoritesJob can cause" do
      folder = create(:favorite_folder, user: user)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      # delete_all, not favorite.destroy: mirrors how FavoriteManager.remove! and
      # TransferFavoritesJob actually remove Favorite rows in production (bypassing
      # callbacks), which is the real shape of the race this test stands in for.
      Favorite.where(id: favorite.id).delete_all

      expect { FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id) }
        .to raise_error(FavoriteFolderManager::Error, "You have not favorited this post")

      # Not just "doesn't raise a raw error" - actually produced no membership row for the
      # now-nonexistent favorite_id, which is what an unguarded upsert would otherwise
      # have attempted and failed on with ActiveRecord::InvalidForeignKey.
      expect(FavoriteFolderMembership.where(user_id: user.id)).to be_empty
    end

    it "raises the normal domain error when moving to root and the favorite was already deleted concurrently (the delete_all-to-root path, not just the upsert-to-folder path)" do
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      Favorite.where(id: favorite.id).delete_all

      expect { FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: nil) }
        .to raise_error(FavoriteFolderManager::Error, "You have not favorited this post")
    end

    it "raises when the destination folder belongs to another user" do
      other_folder = create(:favorite_folder, user: other_user)
      expect { FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: other_folder.id) }
        .to raise_error(FavoriteFolderManager::Error, /does not belong to you/)
      expect(membership_for(post_record)).to be_nil
    end

    it "raises cleanly when the destination folder no longer exists" do
      folder = create(:favorite_folder, user: user)
      folder_id = folder.id
      folder.destroy!
      expect { FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder_id) }
        .to raise_error(FavoriteFolderManager::Error, "Folder not found")
    end

    it "raises when the post is not favorited by the user" do
      other_post = create(:post)
      expect { FavoriteFolderManager.move!(user: user, post: other_post, destination_folder_id: nil) }
        .to raise_error(FavoriteFolderManager::Error, /have not favorited/)
    end

    it "does not change post fav_count or user favorite_count" do
      folder = create(:favorite_folder, user: user)
      favorite_count_before = user.reload.favorite_count

      expect { FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id) }
        .not_to(change { post_record.reload.fav_count })
      expect(user.reload.favorite_count).to eq(favorite_count_before)
    end

    it "enforces one folder per favorite at the model validation level" do
      folder = create(:favorite_folder, user: user)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      duplicate = FavoriteFolderMembership.new(user: user, folder: folder, favorite: favorite,
                                               post_id: favorite.post_id, favorite_created_at: favorite.created_at)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:favorite_id]).to be_present
    end

    it "enforces one folder per favorite at the database level (unique index), bypassing validations" do
      folder = create(:favorite_folder, user: user)
      favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)

      expect do
        # insert! (unlike insert, which defaults to ON CONFLICT DO NOTHING and silently
        # skips) issues a plain INSERT with no conflict handling, so the DB's own unique
        # index is what raises here - not Rails validations, which insert!/insert bypass.
        FavoriteFolderMembership.insert!({ user_id: user.id, folder_id: folder.id, favorite_id: favorite.id,
                                           post_id: favorite.post_id, favorite_created_at: favorite.created_at, },
                                         record_timestamps: true)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
