# frozen_string_literal: true

require "rails_helper"

# Legacy stub kept for jobs enqueued before the pool_string removal; it only
# reindexes affected posts. Delete together with the job when the column drops.
RSpec.describe PostSetPostsSyncJob do
  subject(:job) { described_class }

  include_context "as member"

  describe ".lock_args" do
    it "returns only the set_id, ignoring any extra arguments" do
      expect(job.lock_args([42, { added_ids: [1, 2] }])).to eq([42])
    end
  end

  describe "#perform" do
    let(:post_set) { create(:post_set) }

    context "when the set does not exist" do
      it "does not raise an error" do
        expect { job.perform_now(-1) }.not_to raise_error
      end
    end

    context "when the set has members" do
      let(:post) { create(:post) }

      it "enqueues a BulkIndexUpdateJob for them" do
        post_set.update_column(:post_ids, [post.id])
        expect { job.perform_now(post_set.id) }
          .to have_enqueued_job(BulkIndexUpdateJob).with("Post", [post.id])
      end
    end

    context "when a post still carries a legacy set token without being a member" do
      let(:post) { create(:post) }

      before { Post.where(id: post.id).update_all(pool_string: "set:#{post_set.id}") }

      it "enqueues a BulkIndexUpdateJob for it" do
        post_set.update_column(:post_ids, [])
        expect { job.perform_now(post_set.id) }
          .to have_enqueued_job(BulkIndexUpdateJob).with("Post", [post.id])
      end
    end

    context "when the set is empty and no posts carry its token" do
      it "does not enqueue a BulkIndexUpdateJob" do
        post_set.update_column(:post_ids, [])
        expect { job.perform_now(post_set.id) }
          .not_to have_enqueued_job(BulkIndexUpdateJob)
      end
    end
  end
end
