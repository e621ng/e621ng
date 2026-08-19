# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSetCleanupJob do
  include_context "as admin"

  def perform(type, obj_id)
    described_class.perform_now(type, obj_id)
  end

  describe "#perform" do
    context "with type :pool" do
      let(:pool_id) { 42 }
      let!(:post_in_pool) { create(:post).tap { |p| p.update_columns(pool_ids: [pool_id]) } }
      let!(:post_not_in_pool) { create(:post) }

      before do
        # remove_pool! guards on can_remove_from_pools? which requires account age > 7 days.
        # The system user is created fresh in before(:suite), so we backdate it here.
        # use_transactional_fixtures rolls this back after each example.
        User.system.update_columns(created_at: 8.days.ago)
      end

      it "removes the pool id from the raw pool_ids column" do
        perform(:pool, pool_id)
        expect(post_in_pool.reload[:pool_ids]).not_to include(pool_id)
      end

      it "does not modify posts that do not belong to the pool" do
        perform(:pool, pool_id)
        expect(post_not_in_pool.reload[:pool_ids]).to eq([])
      end

      context "when the post also belongs to other pools" do
        let(:other_pool_id) { 99 }
        let!(:post_in_both) { create(:post).tap { |p| p.update_columns(pool_ids: [pool_id, other_pool_id]) } }

        it "preserves the other pool ids" do
          perform(:pool, pool_id)
          expect(post_in_both.reload[:pool_ids]).to eq([other_pool_id])
        end
      end

      context "when posts.pool_ids drifted from the pool's post_ids" do
        # Regression test: a pool that never listed the post in its own post_ids
        # must still get cleaned out of the post's pool_ids on deletion. The old
        # pool_string-scoped implementation silently skipped such posts.
        let!(:drifted_post) { create(:post).tap { |p| p.update_columns(pool_ids: [pool_id]) } }

        it "clears the stale membership anyway" do
          perform(:pool, pool_id)
          expect(drifted_post.reload[:pool_ids]).to eq([])
        end
      end
    end

    context "with type :set (legacy jobs enqueued before the pool_string removal)" do
      let(:set_id) { 42 }
      let!(:post_in_set) { create(:post).tap { |p| Post.where(id: p.id).update_all(pool_string: "set:#{set_id}") } }

      before { create(:post) } # a post without the token, to prove scoping

      it "enqueues a reindex for posts that carried the set token" do
        expect { perform(:set, set_id) }
          .to have_enqueued_job(BulkIndexUpdateJob).with("Post", [post_in_set.id])
      end

      it "does not enqueue anything when no posts carry the token" do
        expect { perform(:set, 999_999) }.not_to have_enqueued_job(BulkIndexUpdateJob)
      end
    end

    context "when type is passed as a string" do
      let(:pool_id) { 42 }
      let!(:post_in_pool) { create(:post).tap { |p| p.update_columns(pool_ids: [pool_id]) } }

      before { User.system.update_columns(created_at: 8.days.ago) }

      it "converts the string to a symbol and processes correctly" do
        perform("pool", pool_id)
        expect(post_in_pool.reload[:pool_ids]).not_to include(pool_id)
      end
    end

    context "with an invalid type" do
      it "raises ArgumentError" do
        expect { perform(:invalid, 1) }.to raise_error(ArgumentError, /Invalid type/)
      end
    end

    context "when no posts contain the pool" do
      it "does not raise an error" do
        expect { perform(:pool, 999_999) }.not_to raise_error
      end
    end
  end
end
