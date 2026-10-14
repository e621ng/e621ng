# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         PostSet Write Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  let(:set) { create(:post_set) }

  describe "#add!" do
    it "adds the post and refreshes its search index" do
      post = create(:post)
      allow(post).to receive(:update_index)

      set.add!(post)

      expect(set.reload.post_ids).to eq([post.id])
      expect(post).to have_received(:update_index)
    end
  end

  describe "#remove!" do
    it "removes the post and refreshes its search index" do
      post = create(:post)
      set.update_columns(post_ids: [post.id], post_count: 1)
      allow(post).to receive(:update_index)

      set.remove!(post)

      expect(set.reload.post_ids).to eq([])
      expect(post).to have_received(:update_index)
    end
  end

  describe "#add" do
    it "enqueues a reindex for the added posts" do
      posts = create_list(:post, 2)

      expect { set.add(posts.map(&:id)) }
        .to enqueue_sidekiq_job(BulkIndexUpdateJob).with("Post", match_array(posts.map(&:id)))
    end
  end

  describe "#remove" do
    it "enqueues a reindex for the removed posts" do
      posts = create_list(:post, 2)
      set.update_columns(post_ids: posts.map(&:id), post_count: posts.size)

      expect { set.remove(posts.map(&:id)) }
        .to enqueue_sidekiq_job(BulkIndexUpdateJob).with("Post", match_array(posts.map(&:id)))
    end
  end

  describe "#destroy" do
    it "enqueues a reindex for the set's members" do
      posts = create_list(:post, 2)
      set.update_columns(post_ids: posts.map(&:id), post_count: posts.size)
      set.reload

      expect { set.destroy }
        .to enqueue_sidekiq_job(BulkIndexUpdateJob).with("Post", posts.map(&:id))
    end

    it "enqueues nothing for an empty set" do
      set # create before the expectation block
      expect { set.destroy }.not_to enqueue_sidekiq_job(BulkIndexUpdateJob)
    end
  end
end
