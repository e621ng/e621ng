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
      it "adds the pool id to the raw pool_ids column" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        expect(post[:pool_ids]).to include(pool.id)
      end

      it "keeps pool_ids sorted" do
        later_pool = create(:pool)
        earlier_pool = create(:pool)
        post = create(:post, pool_ids: [later_pool.id])

        post.add_pool!(earlier_pool)

        expect(post[:pool_ids]).to eq([later_pool.id, earlier_pool.id].sort)
      end

      it "does not add the pool a second time if already present" do
        pool = create(:pool)
        post = create(:post)
        post.add_pool!(pool)
        post.add_pool!(pool)
        expect(post[:pool_ids].count(pool.id)).to eq(1)
      end
    end

    describe "#remove_pool!" do
      it "removes the pool id from the raw pool_ids column" do
        pool = create(:pool)
        post = create(:post, pool_ids: [pool.id])
        post.remove_pool!(pool)
        expect(post[:pool_ids]).not_to include(pool.id)
      end

      it "keeps other pool ids intact" do
        pool = create(:pool)
        other_pool = create(:pool)
        post = create(:post, pool_ids: [pool.id, other_pool.id].sort)

        post.remove_pool!(pool)

        expect(post[:pool_ids]).to eq([other_pool.id])
      end

      it "does nothing when the pool is not in pool_ids" do
        pool = create(:pool)
        post = create(:post, pool_ids: [])
        post.remove_pool!(pool)
        expect(post[:pool_ids]).to eq([])
      end

      it "does nothing when the user cannot remove from pools" do
        pool = create(:pool)
        post = create(:post, pool_ids: [pool.id])
        allow(CurrentUser.user).to receive(:can_remove_from_pools?).and_return(false)

        post.remove_pool!(pool)

        expect(post[:pool_ids]).to eq([pool.id])
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
      it "returns the raw column value when present" do
        post = build(:post, pool_ids: [42])
        expect(post.pool_ids).to eq([42])
      end

      it "returns an empty array when the column is NULL" do
        post = create(:post)
        post.update_columns(pool_ids: nil)
        post.reload
        expect(post.pool_ids).to eq([])
        expect(post.pools).to be_empty
        expect(post.has_active_pools?).to be false
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
