# frozen_string_literal: true

require "rails_helper"

RSpec.describe TransferFavoritesJob do
  include_context "as admin"

  let(:parent_post) { create(:post) }
  let(:child_post)  { create(:post, parent_id: parent_post.id) }

  def perform(post_id = child_post.id, user_id = CurrentUser.id)
    described_class.perform_now(post_id, user_id)
  end

  # Creates a Favorite and keeps post.fav_string / fav_count consistent.
  # Favorite.create! fires user_status_counter → UserStatus.favorite_count++
  def add_favorite(post, user)
    Favorite.create!(post_id: post.id, user_id: user.id)
    post.update_columns(
      fav_string: "#{post.fav_string} fav:#{user.id}".strip,
      fav_count:  post.fav_count + 1,
    )
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
        it "clears fav_string on the child post" do
          expect(child_post.reload.fav_string).to eq("")
        end

        it "sets fav_count to 0 on the child post" do
          expect(child_post.reload.fav_count).to eq(0)
        end

        it "adds user_a to the parent post fav_string" do
          expect(parent_post.reload.fav_string).to include("fav:#{user_a.id}")
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
