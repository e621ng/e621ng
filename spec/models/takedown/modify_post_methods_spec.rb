# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     Takedown ModifyPostMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  subject(:takedown) { create(:takedown) }

  include_context "as admin"

  # -------------------------------------------------------------------------
  # add_posts_by_ids!
  # -------------------------------------------------------------------------
  describe "#add_posts_by_ids!" do
    let(:post_a) { create(:post) }
    let(:post_b) { create(:post) }

    it "adds new post IDs to the takedown" do
      takedown.add_posts_by_ids!(post_a.id.to_s)
      expect(takedown.reload.post_array).to include(post_a.id)
    end

    it "returns the list of newly added IDs" do
      added = takedown.add_posts_by_ids!(post_a.id.to_s)
      expect(added).to contain_exactly(post_a.id)
    end

    it "does not duplicate IDs that are already present" do
      takedown.add_posts_by_ids!(post_a.id.to_s)
      takedown.add_posts_by_ids!(post_a.id.to_s)
      expect(takedown.reload.post_array.count(post_a.id)).to eq(1)
    end

    it "returns an empty array when all submitted IDs are already present" do
      takedown.add_posts_by_ids!(post_a.id.to_s)
      added = takedown.add_posts_by_ids!(post_a.id.to_s)
      expect(added).to be_empty
    end

    it "accepts multiple IDs in a single call" do
      added = takedown.add_posts_by_ids!("#{post_a.id} #{post_b.id}")
      expect(added).to contain_exactly(post_a.id, post_b.id)
    end

    it "accepts e621 post URLs" do
      added = takedown.add_posts_by_ids!("https://e621.net/posts/#{post_a.id}")
      expect(added).to contain_exactly(post_a.id)
    end

    it "ignores IDs that do not correspond to existing posts (filtered by validate_post_ids)" do
      fake_id = 999_999_997
      takedown.add_posts_by_ids!(fake_id.to_s)
      expect(takedown.reload.post_array).not_to include(fake_id)
    end

    it "persists the change to the database" do
      takedown.add_posts_by_ids!(post_a.id.to_s)
      expect(Takedown.find(takedown.id).post_array).to include(post_a.id)
    end
  end

  # -------------------------------------------------------------------------
  # add_posts_by_tags!
  # -------------------------------------------------------------------------
  describe "#add_posts_by_tags!" do
    it "adds posts that match the given tag query" do
      post = create(:post)
      tag_name = post.tag_array.first
      # Stub to avoid transactional-fixtures / OpenSearch staleness: rolled-back
      # documents persist in the index, so a real search returns stale IDs.
      allow(Post).to receive(:tag_match_system).and_return(Post.where(id: post.id))
      takedown.add_posts_by_tags!(tag_name)
      expect(takedown.reload.post_array).to include(post.id)
    end

    it "does not add deleted posts (system search excludes status:deleted)" do
      post = create(:deleted_post)
      tag_name = post.tag_array.first
      allow(Post).to receive(:tag_match_system).and_return(Post.none)
      takedown.add_posts_by_tags!(tag_name)
      expect(takedown.reload.post_array).not_to include(post.id)
    end
  end

  # -------------------------------------------------------------------------
  # remove_posts_by_ids!
  # -------------------------------------------------------------------------
  describe "#remove_posts_by_ids!" do
    let(:post_a) { create(:post) }
    let(:post_b) { create(:post) }

    before do
      takedown.add_posts_by_ids!("#{post_a.id} #{post_b.id}")
    end

    it "removes the specified post IDs" do
      takedown.remove_posts_by_ids!(post_a.id.to_s)
      expect(takedown.reload.post_array).not_to include(post_a.id)
    end

    it "leaves unremoved IDs intact" do
      takedown.remove_posts_by_ids!(post_a.id.to_s)
      expect(takedown.reload.post_array).to include(post_b.id)
    end

    it "accepts multiple IDs in a single call" do
      takedown.remove_posts_by_ids!("#{post_a.id} #{post_b.id}")
      expect(takedown.reload.post_array).to be_empty
    end

    it "is a no-op for IDs not currently in the takedown" do
      takedown.remove_posts_by_ids!("999999996")
      expect(takedown.reload.post_array).to contain_exactly(post_a.id, post_b.id)
    end

    it "persists the change to the database" do
      takedown.remove_posts_by_ids!(post_a.id.to_s)
      expect(Takedown.find(takedown.id).post_array).not_to include(post_a.id)
    end
  end
end
