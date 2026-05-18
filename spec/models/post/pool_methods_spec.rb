# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "PoolMethods" do
    describe "#belongs_to_pool?" do
      it "returns truthy when the post is in the pool" do
        pool = create(:pool)
        post = build(:post, pool_string: "pool:#{pool.id}")
        expect(post).to be_belongs_to_pool(pool)
      end

      it "returns falsy when the post is not in the pool" do
        pool = create(:pool)
        post = build(:post, pool_string: "")
        expect(post).not_to be_belongs_to_pool(pool)
      end
    end

    describe "#add_pool!" do
      it "appends pool:<id> to pool_string" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        expect(post.pool_string).to include("pool:#{pool.id}")
      end

      it "does not add the pool a second time if already present" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        post.add_pool!(pool)
        expect(post.pool_string.scan("pool:#{pool.id}").size).to eq(1)
      end
    end

    describe "#remove_pool!" do
      it "removes pool:<id> from pool_string" do
        pool = create(:pool)
        post = create(:post, pool_string: "pool:#{pool.id}")
        post.remove_pool!(pool)
        expect(post.pool_string).not_to include("pool:#{pool.id}")
      end

      it "does nothing when the pool is not in pool_string" do
        pool = create(:pool)
        post = create(:post, pool_string: "")
        original = post.pool_string
        post.remove_pool!(pool)
        expect(post.pool_string).to eq(original)
      end
    end

    describe "#has_active_pools?" do
      it "returns false when pool_string is blank" do
        post = build(:post, pool_string: "")
        expect(post.has_active_pools?).to be false
      end

      it "returns true when pool_string contains an active pool" do
        pool = create(:pool, is_active: true)
        post = create(:post, pool_string: "pool:#{pool.id}")
        expect(post.has_active_pools?).to be true
      end
    end

    describe "#pool_ids" do
      it "returns an array of pool ids from pool_string" do
        pool1 = create(:pool)
        pool2 = create(:pool)
        post = build(:post, pool_string: "pool:#{pool1.id} pool:#{pool2.id}")
        expect(post.pool_ids).to include(pool1.id, pool2.id)
      end

      it "returns an empty array when pool_string has no pools" do
        post = build(:post, pool_string: "")
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
