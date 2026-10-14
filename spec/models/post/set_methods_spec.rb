# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "SetMethods" do
    describe "#post_sets" do
      it "finds sets whose post_ids contain the post" do
        set1 = create(:post_set)
        set2 = create(:post_set)
        other_set = create(:post_set)
        post = create(:post)
        set1.update_column(:post_ids, [post.id])
        set2.update_column(:post_ids, [post.id, post.id + 1])

        expect(post.post_sets).to contain_exactly(set1, set2)
        expect(post.post_sets).not_to include(other_set)
      end

      it "returns no sets for a new record" do
        post = build(:post)
        expect(post.post_sets).to be_empty
      end
    end

    describe "#give_post_sets_to_parent" do
      it "removes the post from its sets when expunged without a parent" do
        set  = create(:post_set)
        post = create(:post)
        set.update_column(:post_ids, [post.id])
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
