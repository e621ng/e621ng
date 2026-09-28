# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransferFavoritesJob do
  include_context "as admin"

  let(:parent_post) { create(:post) }
  let(:child_post)  { create(:post, parent_id: parent_post.id) }

  def perform(post_id = child_post.id, user_id = CurrentUser.id)
    described_class.new.perform(post_id, user_id)
  end

  # Creates a Favorite and keeps post.fav_count consistent.
  # Favorite.create! fires user_status_counter → UserStatus.favorite_count++
  def add_favorite(post, user)
    Favorite.create!(post_id: post.id, user_id: user.id)
    post.update_columns(fav_count: Favorite.where(post_id: post.id).count)
  end

  describe "#perform" do
    context "when the post does not exist" do
      it "returns without error" do
        expect { perform(0, create(:user).id) }.not_to raise_error
      end
    end

    context "when the user does not exist" do
      it "returns without error" do
        expect { perform(child_post.id, 0) }.not_to raise_error
      end
    end

    context "when the post has no parent" do
      let(:child_post) { create(:post) }

      before { add_favorite(child_post, create(:user)) }

      it "does not create any PostEvents" do
        expect { perform }.not_to change(PostEvent, :count)
      end

      it "does not delete any Favorites" do
        expect { perform }.not_to change(Favorite, :count)
      end
    end

    context "when the post has no favorites" do
      it "does not create any PostEvents" do
        child_post # ensure exists with no favorites
        expect { perform }.not_to change(PostEvent, :count)
      end

      it "does not delete any Favorites" do
        child_post
        expect { perform }.not_to change(Favorite, :count)
      end
    end

    context "when the transfer can proceed" do
      let(:user_a) { create(:user) } # favorites child only
      let(:user_b) { create(:user) } # favorites both child and parent
      let(:user_c) { create(:user) } # favorites parent only

      before do
        add_favorite(child_post,  user_a)
        add_favorite(child_post,  user_b)
        add_favorite(parent_post, user_b)
        add_favorite(parent_post, user_c)
        perform
      end

      describe "Favorite record mutations" do
        it "deletes all Favorite records for the child post" do
          expect(Favorite.where(post_id: child_post.id)).to be_empty
        end

        it "creates a Favorite on the parent for user_a who was not already there" do
          expect(Favorite.find_by(post_id: parent_post.id, user_id: user_a.id)).to be_present
        end

        it "does not create a duplicate Favorite on the parent for user_b" do
          expect(Favorite.where(post_id: parent_post.id, user_id: user_b.id).count).to eq(1)
        end
      end

      describe "post data updates" do
        it "sets fav_count to 0 on the child post" do
          expect(child_post.reload.fav_count).to eq(0)
        end

        it "increments parent fav_count by the number of newly added users" do
          # parent had user_b and user_c (2); user_a is added (1 new) → 3
          expect(parent_post.reload.fav_count).to eq(3)
        end
      end

      describe "UserStatus favorite counts" do
        it "does not change user_a's favorite_count (transferred child → parent, net zero)" do
          expect(user_a.user_status.reload.favorite_count).to eq(1)
        end

        it "decrements user_b's favorite_count by 1 (was on parent already, lost child)" do
          expect(user_b.user_status.reload.favorite_count).to eq(1)
        end

        it "does not change user_c's favorite_count (only had parent, unaffected)" do
          expect(user_c.user_status.reload.favorite_count).to eq(1)
        end
      end

      describe "PostEvent creation" do
        it "creates a favorites_moved event on the child post" do
          event = PostEvent.find_by(post_id: child_post.id, action: "favorites_moved")
          expect(event).to be_present
          expect(event.extra_data).to include("parent_id" => parent_post.id)
        end

        it "creates a favorites_received event on the parent post" do
          event = PostEvent.find_by(post_id: parent_post.id, action: "favorites_received")
          expect(event).to be_present
          expect(event.extra_data).to include("child_id" => child_post.id)
        end
      end

      describe "bit-flag cleanup" do
        it "clears the favorites_transfer_in_progress flag from the child post" do
          expect(child_post.reload.favorites_transfer_in_progress).to be false
        end

        it "clears the favorites_transfer_in_progress flag from the parent post" do
          expect(parent_post.reload.favorites_transfer_in_progress).to be false
        end
      end
    end

    describe "folder placement carry-over" do
      let(:user_a) { create(:user) }
      let(:user_b) { create(:user) }

      def parent_favorite_for(user)
        Favorite.for_user(user.id).find_by(post_id: parent_post.id)
      end

      def membership_for(favorite)
        FavoriteFolderMembership.find_by(favorite_id: favorite.id)
      end

      it "carries a filed child favorite's folder onto the new parent favorite" do
        folder = create(:favorite_folder, user: user_a)
        add_favorite(child_post, user_a)
        child_favorite = Favorite.for_user(user_a.id).find_by(post_id: child_post.id)
        create(:favorite_folder_membership, user: user_a, folder: folder, favorite: child_favorite)

        perform(child_post.id, user_a.id)

        favorite = parent_favorite_for(user_a)
        membership = membership_for(favorite)
        expect(membership).to be_present
        expect(membership.folder_id).to eq(folder.id)
        expect(membership.post_id).to eq(parent_post.id)
        expect(membership.favorite_created_at).to eq(favorite.created_at)
      end

      it "leaves the new parent favorite unfiled when the child was unfiled" do
        add_favorite(child_post, user_a)
        perform(child_post.id, user_a.id)
        expect(membership_for(parent_favorite_for(user_a))).to be_nil
      end

      it "does not touch an existing parent favorite's existing membership, regardless of the child's own filing" do
        folder = create(:favorite_folder, user: user_a)
        add_favorite(parent_post, user_a)
        parent_favorite = parent_favorite_for(user_a)
        membership = create(:favorite_folder_membership, user: user_a, folder: folder, favorite: parent_favorite)
        add_favorite(child_post, user_a) # user_a favorited both child and parent already

        perform(child_post.id, user_a.id)

        expect(membership.reload.folder_id).to eq(folder.id)
        expect(membership.reload.favorite_id).to eq(parent_favorite.id)
      end

      it "does not file an existing parent favorite that has no membership, even if the child was filed" do
        folder = create(:favorite_folder, user: user_a)
        add_favorite(parent_post, user_a)
        add_favorite(child_post, user_a)
        child_favorite = Favorite.for_user(user_a.id).find_by(post_id: child_post.id)
        create(:favorite_folder_membership, user: user_a, folder: folder, favorite: child_favorite)

        perform(child_post.id, user_a.id)

        expect(membership_for(parent_favorite_for(user_a))).to be_nil
      end

      it "creates no membership, and does not raise, when the folder no longer exists by the live_folder_ids pre-check" do
        add_favorite(parent_post, user_a)
        favorite = parent_favorite_for(user_a)
        row = { "id" => favorite.id, "user_id" => user_a.id, "created_at" => favorite.created_at }

        expect do
          described_class.new.send(:carry_over_folder_placements, parent_post, [row], { user_a.id => 0 })
        end.not_to raise_error
        expect(membership_for(favorite)).to be_nil
      end

      it "isolates an insert-time race (folder deleted after the pre-check) to just that folder, proving transaction/savepoint recovery rather than merely Ruby exception recovery" do
        folder_a = create(:favorite_folder, user: user_a, name: "folder_a")
        folder_b = create(:favorite_folder, user: user_b, name: "folder_b")
        add_favorite(child_post, user_a)
        add_favorite(child_post, user_b)
        favorite_a = Favorite.for_user(user_a.id).find_by(post_id: child_post.id)
        favorite_b = Favorite.for_user(user_b.id).find_by(post_id: child_post.id)
        create(:favorite_folder_membership, user: user_a, folder: folder_a, favorite: favorite_a)
        create(:favorite_folder_membership, user: user_b, folder: folder_b, favorite: favorite_b)

        # Deletes folder_b BEFORE the fast-path savepoint opens (not inside it), so the
        # delete survives that savepoint's own rollback - exactly like a genuinely
        # concurrent, already-committed FavoriteFolderManager.delete! would. Stubbing
        # insert_all itself instead would nest the delete inside the same savepoint as the
        # failing insert, and rolling that savepoint back would silently undo the delete
        # too - looking like isolation worked without actually proving it against a real
        # independently-committed race.
        raced = false
        allow(FavoriteFolderMembership).to receive(:transaction).and_wrap_original do |original, *args, **kwargs, &block|
          unless raced
            raced = true
            FavoriteFolder.where(id: folder_b.id).delete_all
          end
          original.call(*args, **kwargs, &block)
        end

        # One perform call transfers every favoriter of child_post at once (user_a and
        # user_b both), so both rows land in the same bulk insert_all attempt.
        expect { perform(child_post.id, user_a.id) }.not_to raise_error

        expect(membership_for(parent_favorite_for(user_a))&.folder_id).to eq(folder_a.id)
        expect(parent_favorite_for(user_b)).to be_present
        expect(membership_for(parent_favorite_for(user_b))).to be_nil
      end
    end

    # cleanup_orphaned_child_favorites is a race-condition safety net: the main delete_all
    # removes all child favorites before this method runs, so the only way it can find records
    # is if a new favorite was inserted concurrently. We call the private method directly to
    # test its behaviour without simulating a live race condition.
    context "when orphaned Favorite records exist on the child post" do
      let(:orphan_user) { create(:user) }
      let(:job) { described_class.new }

      before do
        Favorite.create!(post_id: child_post.id, user_id: orphan_user.id)
      end

      it "deletes the orphaned Favorite" do
        job.send(:cleanup_orphaned_child_favorites, child_post)
        expect(Favorite.find_by(post_id: child_post.id, user_id: orphan_user.id)).to be_nil
      end

      it "recalculates favorite_count for the user with the orphaned Favorite to 0" do
        job.send(:cleanup_orphaned_child_favorites, child_post)
        expect(orphan_user.user_status.reload.favorite_count).to eq(0)
      end
    end
  end
end
