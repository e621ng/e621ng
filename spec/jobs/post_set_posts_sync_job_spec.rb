# frozen_string_literal: true

require "rails_helper"

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

    context "when a post is in post_ids but missing the set id" do
      let(:post) { create(:post) }

      before { Post.where(id: post.id).update_all(set_ids: []) }

      it "adds the set id to set_ids" do
        post_set.update_column(:post_ids, [post.id])
        job.perform_now(post_set.id)
        expect(post.reload.set_ids).to include(post_set.id)
      end

      it "enqueues a BulkIndexUpdateJob for the post" do
        post_set.update_column(:post_ids, [post.id])
        expect { job.perform_now(post_set.id) }
          .to have_enqueued_job(BulkIndexUpdateJob).with("Post", [post.id])
      end
    end

    context "when a post has the set id but is not in post_ids" do
      let(:post) { create(:post) }

      before { Post.where(id: post.id).update_all(set_ids: [post_set.id]) }

      it "removes the set id from set_ids" do
        post_set.update_column(:post_ids, [])
        job.perform_now(post_set.id)
        expect(post.reload.set_ids).not_to include(post_set.id)
      end

      it "enqueues a BulkIndexUpdateJob for the post" do
        post_set.update_column(:post_ids, [])
        expect { job.perform_now(post_set.id) }
          .to have_enqueued_job(BulkIndexUpdateJob).with("Post", [post.id])
      end
    end

    context "when a post is correctly in both post_ids and set_ids" do
      let(:post) { create(:post) }

      before { Post.where(id: post.id).update_all(set_ids: [post_set.id]) }

      it "does not change set_ids" do
        post_set.update_column(:post_ids, [post.id])
        expect { job.perform_now(post_set.id) }
          .not_to(change { post.reload.set_ids })
      end

      it "does not enqueue a BulkIndexUpdateJob" do
        post_set.update_column(:post_ids, [post.id])
        expect { job.perform_now(post_set.id) }
          .not_to have_enqueued_job(BulkIndexUpdateJob)
      end
    end

    context "when a post is correctly absent from both post_ids and set_ids" do
      let(:post) { create(:post) }

      before { Post.where(id: post.id).update_all(set_ids: []) }

      it "does not change set_ids" do
        post_set.update_column(:post_ids, [])
        expect { job.perform_now(post_set.id) }
          .not_to(change { post.reload.set_ids })
      end

      it "does not enqueue a BulkIndexUpdateJob" do
        post_set.update_column(:post_ids, [])
        expect { job.perform_now(post_set.id) }
          .not_to have_enqueued_job(BulkIndexUpdateJob)
      end
    end
  end
end
