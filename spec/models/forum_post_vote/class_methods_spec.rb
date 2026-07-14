# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumPostVote do
  include_context "as member"

  let(:forum_post) { create(:forum_post) }
  let!(:vote) do
    ForumPostVote.create!(
      creator: CurrentUser.user,
      forum_post: forum_post,
      score: 1,
    )
  end

  # ---------------------------------------------------------------------------
  # #update_vote_score (after_commit callback)
  # ---------------------------------------------------------------------------
  describe "after_commit" do
    it "calls forum_post.update_vote_score after a successful save" do
      allow(forum_post).to receive(:update_vote_score)
      vote.save!
      expect(forum_post).to have_received(:update_vote_score)
    end

    it "calls forum_post.update_vote_score after being destoryed" do
      allow(forum_post).to receive(:update_vote_score)
      vote.destroy!
      expect(forum_post).to have_received(:update_vote_score)
    end
  end
end
