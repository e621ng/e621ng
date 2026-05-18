# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "SetMethods" do
    describe "#belongs_to_post_set" do
      it "returns truthy when the set id is present in set_ids" do
        set  = create(:post_set)
        post = build(:post, set_ids: [set.id])
        expect(post.belongs_to_post_set(set)).to be_truthy
      end

      it "returns falsy when the set id is absent" do
        set  = create(:post_set)
        post = build(:post, set_ids: [])
        expect(post.belongs_to_post_set(set)).to be_falsy
      end
    end

    describe "#add_set!" do
      it "adds set id to set_ids" do
        set  = create(:post_set)
        post = create(:post)
        post.add_set!(set)
        expect(post.set_ids).to include(set.id)
      end

      it "does not add the same set twice" do
        set  = create(:post_set)
        post = create(:post)
        post.add_set!(set)
        post.add_set!(set)
        expect(post.set_ids.count(set.id)).to eq(1)
      end
    end

    describe "#remove_set!" do
      it "removes set id from set_ids" do
        set  = create(:post_set)
        post = create(:post, set_ids: [set.id])
        post.remove_set!(set)
        expect(post.set_ids).not_to include(set.id)
      end
    end

    describe "#set_ids" do
      it "returns an array of set ids" do
        set1 = create(:post_set)
        set2 = create(:post_set)
        post = build(:post, set_ids: [set1.id, set2.id])
        expect(post.set_ids).to include(set1.id, set2.id)
      end

      it "returns an empty array when no sets are in set_ids" do
        post = build(:post, set_ids: [])
        expect(post.set_ids).to eq([])
      end
    end

    describe "#give_post_sets_to_parent" do
      it "removes the post from its sets when expunged without a parent" do
        set  = create(:post_set)
        post = create(:post, set_ids: [set.id])
        post.expunge!
        expect(set.reload.post_ids).not_to include(post.id)
      end

      it "transfers the post's set membership to the parent when transfer_on_delete is true" do
        parent = create(:post)
        post_set = create(:post_set, creator: CurrentUser.user, transfer_on_delete: true)
        post = create(:post, parent: parent)
        post_set.add!(post)

        post.give_post_sets_to_parent

        expect(post_set.reload.post_ids).to include(parent.id)
        expect(post_set.reload.post_ids).not_to include(post.id)
      end

      it "does not transfer set membership when transfer_on_delete is false" do
        parent = create(:post)
        post_set = create(:post_set, creator: CurrentUser.user, transfer_on_delete: false)
        post = create(:post, parent: parent)
        post_set.add!(post)

        post.give_post_sets_to_parent

        expect(post_set.reload.post_ids).not_to include(parent.id)
      end
    end
  end
end
