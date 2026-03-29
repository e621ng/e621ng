# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "SetMethods" do
    describe "#belongs_to_post_set" do
      it "returns truthy when the set id is present in pool_string" do
        set  = create(:post_set)
        post = build(:post, pool_string: "set:#{set.id}")
        expect(post.belongs_to_post_set(set)).to be_truthy
      end

      it "returns falsy when the set id is absent" do
        set  = create(:post_set)
        post = build(:post, pool_string: "")
        expect(post.belongs_to_post_set(set)).to be_falsy
      end
    end

    describe "#add_set!" do
      it "adds set:<id> to pool_string" do
        set  = create(:post_set)
        post = create(:post)
        post.add_set!(set)
        expect(post.pool_string).to include("set:#{set.id}")
      end

      it "does not add the same set twice" do
        set  = create(:post_set)
        post = create(:post)
        post.add_set!(set)
        post.add_set!(set)
        expect(post.pool_string.scan("set:#{set.id}").size).to eq(1)
      end
    end

    describe "#remove_set!" do
      it "removes set:<id> from pool_string" do
        set  = create(:post_set)
        post = create(:post, pool_string: "set:#{set.id}")
        post.remove_set!(set)
        expect(post.pool_string).not_to include("set:#{set.id}")
      end
    end

    describe "#set_ids" do
      it "returns an array of set ids from pool_string" do
        set1 = create(:post_set)
        set2 = create(:post_set)
        post = build(:post, pool_string: "set:#{set1.id} set:#{set2.id}")
        expect(post.set_ids).to include(set1.id, set2.id)
      end

      it "returns an empty array when no sets are in pool_string" do
        post = build(:post, pool_string: "")
        expect(post.set_ids).to eq([])
      end
    end

    describe "#give_post_sets_to_parent" do
      it "removes the post from its sets when expunged without a parent" do
        set  = create(:post_set)
        post = create(:post, pool_string: "set:#{set.id}")
        post.expunge!
        # The post was removed from the set
        expect(set.reload.post_ids).not_to include(post.id)
      end
    end
  end
end
