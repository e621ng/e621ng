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
  end
end
