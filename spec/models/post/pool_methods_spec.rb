# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "PoolMethods" do
    describe "#belongs_to_pool?" do
      it "returns truthy when the post is in the pool" do
        pool = create(:pool)
        post = build(:post, pool_ids: [pool.id])
        expect(post).to be_belongs_to_pool(pool)
      end

      it "returns falsy when the post is not in the pool" do
        pool = create(:pool)
        post = build(:post, pool_ids: [])
        expect(post).not_to be_belongs_to_pool(pool)
      end
    end

    describe "#add_pool!" do
      it "adds pool id to pool_ids" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        expect(post.pool_ids).to include(pool.id)
      end

      it "does not add the pool a second time if already present" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        post.add_pool!(pool)
        expect(post.pool_ids.count(pool.id)).to eq(1)
      end
    end

    describe "#remove_pool!" do
      it "removes pool id from pool_ids" do
        pool = create(:pool)
        post = create(:post, pool_ids: [pool.id])
        post.remove_pool!(pool)
        expect(post.pool_ids).not_to include(pool.id)
      end

      it "does nothing when the pool is not in pool_ids" do
        pool = create(:pool)
        post = create(:post, pool_ids: [])
        original = post.pool_ids.dup
        post.remove_pool!(pool)
        expect(post.pool_ids).to eq(original)
      end
    end

    describe "#has_active_pools?" do
      it "returns false when pool_ids is empty" do
        post = build(:post, pool_ids: [])
        expect(post.has_active_pools?).to be false
      end

      it "returns true when pool_ids contains an active pool" do
        pool = create(:pool, is_active: true)
        post = create(:post, pool_ids: [pool.id])
        expect(post.has_active_pools?).to be true
      end
    end

    describe "#pool_ids" do
      it "returns an array of pool ids" do
        pool1 = create(:pool)
        pool2 = create(:pool)
        post = build(:post, pool_ids: [pool1.id, pool2.id])
        expect(post.pool_ids).to include(pool1.id, pool2.id)
      end

      it "returns an empty array when pool_ids has no pools" do
        post = build(:post, pool_ids: [])
        expect(post.pool_ids).to eq([])
      end
    end

    describe "#remove_from_all_pools" do
      it "removes the post from each pool it belongs to" do
        pool1 = create(:pool)
        pool2 = create(:pool)
        post  = create(:post)
        pool1.add!(post)
        pool2.add!(post)

        post.remove_from_all_pools

        expect(pool1.reload.post_ids).not_to include(post.id)
        expect(pool2.reload.post_ids).not_to include(post.id)
      end
    end
  end
end
