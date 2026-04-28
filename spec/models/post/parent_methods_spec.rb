# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ParentMethods" do
    describe "#update_has_children_flag" do
      it "sets has_children to true when the post has children" do
        parent = create(:post)
        create(:post, parent: parent)
        parent.update_has_children_flag
        expect(parent.reload.has_children).to be true
      end

      it "sets has_children to false when all children are removed" do
        parent = create(:post)
        child = create(:post, parent: parent)
        child.update!(parent_id: nil)
        parent.update_has_children_flag
        expect(parent.reload.has_children).to be false
      end

      it "sets has_active_children to true when non-deleted children exist" do
        parent = create(:post)
        create(:post, parent: parent)
        parent.update_has_children_flag
        expect(parent.reload.has_active_children).to be true
      end

      it "sets has_active_children to false when all children are deleted" do
        parent = create(:post)
        child = create(:post, parent: parent)
        parent.update_has_children_flag
        child.update_columns(is_deleted: true)
        parent.update_has_children_flag
        expect(parent.reload.has_active_children).to be false
      end
    end

    describe "has_children flag is updated automatically" do
      it "sets has_children on the parent when a child is saved with that parent" do
        parent = create(:post)
        create(:post, parent: parent)
        expect(parent.reload.has_children).to be true
      end

      it "updates has_children on the old parent when a child is reparented" do
        parent = create(:post)
        child  = create(:post, parent: parent)
        child.update!(parent_id: nil)
        expect(parent.reload.has_children).to be false
      end
    end

    describe "#has_visible_children?" do
      it "returns true when the post has active (non-deleted) children" do
        parent = create(:post)
        create(:post, parent: parent)
        parent.reload
        expect(parent.has_visible_children?).to be true
      end

      it "returns false when the post has no children" do
        post = create(:post)
        expect(post.has_visible_children?).to be false
      end

      it "returns true for a deleted parent that still has children" do
        parent = create(:post)
        create(:post, parent: parent)
        parent.update_columns(is_deleted: true)
        parent.reload
        expect(parent.has_visible_children?).to be true
      end
    end

    describe "#parent_exists?" do
      it "returns true when parent_id points to an existing post" do
        parent = create(:post)
        child  = create(:post, parent: parent)
        expect(child.parent_exists?).to be true
      end

      it "returns false when parent_id is nil" do
        post = create(:post)
        expect(post.parent_exists?).to be false
      end
    end

    describe "#children_ids" do
      it "returns a space-separated string of child post ids" do
        parent = create(:post)
        child1 = create(:post, parent: parent)
        child2 = create(:post, parent: parent)
        ids = parent.reload.children_ids.split.map(&:to_i)
        expect(ids).to include(child1.id, child2.id)
      end

      it "returns nil when the post has no children" do
        post = create(:post)
        expect(post.children_ids).to be_nil
      end
    end

    describe "update_children_on_destroy" do
      it "promotes the eldest child to top-level when the parent is expunged" do
        parent = create(:post)
        child1 = create(:post, parent: parent)
        child2 = create(:post, parent: parent)

        parent.expunge!

        expect(child1.reload.parent_id).to be_nil
        expect(child2.reload.parent_id).to eq(child1.id)
      end
    end

    describe "#give_favorites_to_parent" do
      it "enqueues a TransferFavoritesJob" do
        parent = create(:post)
        child  = create(:post, parent: parent)
        expect { child.give_favorites_to_parent }.to have_enqueued_job(TransferFavoritesJob)
      end
    end

    describe "Post.cleanup_stuck_favorite_transfer_flags!" do
      it "returns 0 when no posts have the stuck flag" do
        expect(Post.cleanup_stuck_favorite_transfer_flags!).to eq(0)
      end

      it "clears the favorites_transfer_in_progress flag and returns the count of affected posts" do
        post = create(:post)
        flag_value = Post.flag_value_for("favorites_transfer_in_progress")
        post.update_columns(bit_flags: flag_value)

        result = Post.cleanup_stuck_favorite_transfer_flags!
        expect(result).to eq(1)
        expect(post.reload.bit_flags & flag_value).to eq(0)
      end
    end

    describe "#has_visible_children (alias)" do
      it "returns the same value as has_visible_children?" do
        parent = create(:post)
        create(:post, parent: parent)
        parent.reload
        expect(parent.has_visible_children).to eq(parent.has_visible_children?)
      end
    end

    describe "#inject_children" do
      it "stores the provided ids so that #children_ids returns them as a space-separated string" do
        parent = create(:post)
        child1 = create(:post, parent: parent)
        child2 = create(:post, parent: parent)
        parent.reload
        parent.inject_children([child1, child2])
        expect(parent.children_ids).to eq("#{child1.id} #{child2.id}")
      end
    end

    describe "#set_merge_edit_reason" do
      it "sets parent.edit_reason when the post has a parent" do
        parent = create(:post)
        child  = create(:post, parent: parent)
        child.set_merge_edit_reason
        expect(parent.edit_reason).to eq("Merged from post ##{child.id}")
      end

      it "does nothing when the post has no parent" do
        post = create(:post, parent_id: nil)
        expect { post.set_merge_edit_reason }.not_to raise_error
      end
    end
  end
end
