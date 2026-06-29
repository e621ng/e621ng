# frozen_string_literal: true

require "rails_helper"

RSpec.describe VoteTrends do
  include_context "as admin"
  describe ".vote_abuse_patterns" do
    let(:user) { create(:user) }
    let(:uploader) { create(:user) }

    let!(:shared_post) { create(:post, tag_string: "tag_one shared", uploader: uploader, score: 10) }
    let!(:other_post) { create(:post, tag_string: "tag_one other", uploader: uploader, score: 2) }

    before do
      create(:post_vote, post: shared_post, user: user, score: 1)
      create(:post_vote, post: other_post, user: user, score: 1)
    end

    it "returns an array of tag-weight pairs" do
      result = described_class.vote_abuse_patterns(user: user, limit: 10, threshold: 0.0001)
      expect(result).to be_an(Array)
      # each element should be a two-element tuple [tag_or_struct, weight]
      expect(result.first.size).to eq(2) if result.any?
    end

    it "honors the duration filter" do
      # move existing votes outside the duration window and expect no recent results
      PostVote.where(user_id: user.id).update_all(created_at: 10.days.ago, updated_at: 10.days.ago)
      recent = described_class.vote_abuse_patterns(user: user, duration: 1)
      expect(recent).to be_empty
    end

    it "honors the duration filter when duration is a string" do
      # move existing votes outside the duration window and expect no recent results
      PostVote.where(user_id: user.id).update_all(created_at: 10.days.ago, updated_at: 10.days.ago)
      recent = described_class.vote_abuse_patterns(user: user, duration: "1")
      expect(recent).to be_empty
    end

    it "returns arrays for both vote_normality settings" do
      with_norm = described_class.vote_abuse_patterns(user: user, vote_normality: true)
      without_norm = described_class.vote_abuse_patterns(user: user, vote_normality: false)
      expect(with_norm).to be_an(Array)
      expect(without_norm).to be_an(Array)
    end

    it "returns empty for high threshold" do
      high = described_class.vote_abuse_patterns(user: user, threshold: 1000.0)
      expect(high).to be_empty
    end

    it "skips votes without posts" do
      vote = instance_double(PostVote, post: nil, score: 1, updated_at: Time.current)

      post_votes_relation = instance_double(ActiveRecord::Relation)
      allow(user).to receive(:post_votes).and_return(post_votes_relation)
      allow(post_votes_relation).to receive_messages(includes: post_votes_relation, order: post_votes_relation, limit: post_votes_relation, to_a: [vote])

      expect(described_class.vote_abuse_patterns(user: user)).to eq([])
    end

    it "handles missing tag records and zero tag post counts" do
      create(:tag, name: "known_tag")
      post = instance_double(Post, tag_array: %w[missing_tag known_tag], uploader_id: 12_345, rating: nil, score: 1, up_score: 1, down_score: 0, tag_count: 1)
      vote = instance_double(PostVote, post: post, score: 1, updated_at: Time.current)

      post_votes_relation = instance_double(ActiveRecord::Relation)
      allow(user).to receive(:post_votes).and_return(post_votes_relation)
      allow(post_votes_relation).to receive_messages(includes: post_votes_relation, order: post_votes_relation, limit: post_votes_relation, to_a: [vote])

      result = described_class.vote_abuse_patterns(user: user)

      expect(result.map { |trend_tag, _| trend_tag.name }).to include("known_tag", "uploader:!12345")
      expect(result.map { |trend_tag, _| trend_tag.name }).not_to include("missing_tag")
      expect(result.find { |trend_tag, _| trend_tag.name == "uploader:!12345" }.first.post_count).to eq(0)
    end

    it "includes uploader and rating keys when present" do
      uploader_user = create(:user)
      tag = create(:tag, name: "known_tag")
      post = instance_double(Post, tag_array: ["known_tag"], uploader_id: uploader_user.id, rating: "s", score: 1, up_score: 1, down_score: 0, tag_count: 1)
      vote = instance_double(PostVote, post: post, score: 1, updated_at: Time.current)

      post_votes_relation = instance_double(ActiveRecord::Relation)
      allow(user).to receive(:post_votes).and_return(post_votes_relation)
      allow(post_votes_relation).to receive_messages(includes: post_votes_relation, order: post_votes_relation, limit: post_votes_relation, to_a: [vote])

      result = described_class.vote_abuse_patterns(user: user)

      expect(result.map { |trend_tag, _| trend_tag.name }).to include("known_tag", "uploader:#{uploader_user.name}", "rating:s")
      expect(result.map { |trend_tag, _| trend_tag.post_count }).to include(tag.post_count)
    end

    it "does not add uploader counts when uploader_id is absent" do
      create(:tag, name: "orphan_tag")
      post = instance_double(Post, tag_array: ["orphan_tag"], uploader_id: nil, rating: nil, score: 1, up_score: 1, down_score: 0, tag_count: 1)
      vote = instance_double(PostVote, post: post, score: 1, updated_at: Time.current)

      post_votes_relation = instance_double(ActiveRecord::Relation)
      allow(user).to receive(:post_votes).and_return(post_votes_relation)
      allow(post_votes_relation).to receive_messages(includes: post_votes_relation, order: post_votes_relation, limit: post_votes_relation, to_a: [vote])

      result = described_class.vote_abuse_patterns(user: user)

      expect(result.map { |trend_tag, _| trend_tag.name }).to eq(["orphan_tag"])
    end

    it "prevents excessive limits with empty return" do
      expect do
        described_class.vote_abuse_patterns(user: user, limit: Danbooru.config.post_vote_limit + 1)
      end.not_to raise_error
    end
  end

  describe ".calculate_vote_weight" do
    let(:vote) { instance_double(PostVote, score: 1) }

    it "returns 0 when the post has no tag count" do
      post = instance_double(Post, tag_count: 0, up_score: 1, down_score: 0)

      expect(described_class.calculate_vote_weight(vote, post)).to eq(0)
    end

    it "uses vote normality when enabled" do
      post = instance_double(Post, tag_count: 2, up_score: 3, down_score: -1)

      expect(described_class.calculate_vote_weight(vote, post, vote_normality: true)).to eq(0.25)
    end

    it "ignores vote normality when disabled" do
      post = instance_double(Post, tag_count: 2, up_score: 3, down_score: -1)

      expect(described_class.calculate_vote_weight(vote, post, vote_normality: false)).to eq(0.5)
    end
  end

  describe ".trend_tag_for" do
    it "falls back to the uploader id when the user is missing" do
      trend_tag = described_class.trend_tag_for("uploader:!123", {}, {}, {})

      expect(trend_tag.name).to eq("uploader:!123")
      expect(trend_tag.uploader_id).to eq(123)
      expect(trend_tag.post_count).to eq(0)
      expect(trend_tag.uploader).to be_nil
    end
  end
end
