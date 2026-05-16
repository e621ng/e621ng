# frozen_string_literal: true

require "rails_helper"

RSpec.describe VoteManager::VoteAbuseMethods do
  include_context "as admin"
  describe ".vote_abuse_patterns" do
    let(:user) { create(:user) }
    let(:uploader) { create(:user) }

    let!(:post1) { create(:post, tag_string: "tag_one shared", uploader: uploader, score: 10) }
    let!(:post2) { create(:post, tag_string: "tag_one other", uploader: uploader, score: 2) }

    before do
      create(:post_vote, post: post1, user: user, score: 1)
      create(:post_vote, post: post2, user: user, score: 1)
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
  end
end
