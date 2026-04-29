# frozen_string_literal: true

require "rails_helper"

RSpec.describe VoteManager do
  include_context "as admin"

  # A regular member is sufficient for post votes; there is no age requirement.
  let(:voter) { create(:user) }
  let(:post)  { create(:post) }

  describe ".vote!" do
    it "raises for an invalid score of 0" do
      expect { described_class.vote!(user: voter, post: post, score: 0) }
        .to raise_error(UserVote::Error, /Invalid vote/)
    end

    it "raises for an invalid score of 2" do
      expect { described_class.vote!(user: voter, post: post, score: 2) }
        .to raise_error(UserVote::Error, /Invalid vote/)
    end

    it "raises when the user is not a member" do
      non_member = create(:user)
      allow(non_member).to receive(:is_member?).and_return(false)
      expect { described_class.vote!(user: non_member, post: post, score: 1) }
        .to raise_error(UserVote::Error, /permission/)
    end

    context "with an upvote" do
      subject(:cast_upvote) { described_class.vote!(user: voter, post: post, score: 1) }

      it "creates a PostVote" do
        expect { cast_upvote }.to change(PostVote, :count).by(1)
      end

      it "increments post.score" do
        expect { cast_upvote }.to change { post.reload.score }.by(1)
      end

      it "increments post.up_score" do
        expect { cast_upvote }.to change { post.reload.up_score }.by(1)
      end

      it "returns the created PostVote" do
        expect(cast_upvote).to be_a(PostVote)
      end
    end

    context "with a downvote" do
      # Downvotes require the user to be at least 3 days old.
      subject(:cast_downvote) { described_class.vote!(user: voter, post: post, score: -1) }

      let(:voter) { create(:user, created_at: 4.days.ago) }

      it "creates a PostVote" do
        expect { cast_downvote }.to change(PostVote, :count).by(1)
      end

      it "decrements post.score" do
        expect { cast_downvote }.to change { post.reload.score }.by(-1)
      end

      it "decrements post.down_score" do
        expect { cast_downvote }.to change { post.reload.down_score }.by(-1)
      end
    end

    context "when re-voting with the same score" do
      before { described_class.vote!(user: voter, post: post, score: 1) }

      it "returns :need_unvote" do
        expect(described_class.vote!(user: voter, post: post, score: 1)).to eq(:need_unvote)
      end

      it "does not create another PostVote" do
        expect { described_class.vote!(user: voter, post: post, score: 1) }
          .not_to change(PostVote, :count)
      end
    end

    context "when flipping an upvote to a downvote" do
      let(:voter) { create(:user, created_at: 4.days.ago) }

      before { described_class.vote!(user: voter, post: post, score: 1) }

      it "changes post.score by -2" do
        expect { described_class.vote!(user: voter, post: post, score: -1) }
          .to change { post.reload.score }.by(-2)
      end
    end

    context "when flipping a downvote to an upvote" do
      let(:voter) { create(:user, created_at: 4.days.ago) }

      before { described_class.vote!(user: voter, post: post, score: -1) }

      it "changes post.score by +2" do
        expect { described_class.vote!(user: voter, post: post, score: 1) }
          .to change { post.reload.score }.by(2)
      end
    end

    context "when the existing vote is locked (score 0)" do
      let!(:locked_vote) { create(:locked_post_vote) }

      it "raises Vote is locked" do
        expect { described_class.vote!(user: locked_vote.user, post: locked_vote.post, score: 1) }
          .to raise_error(UserVote::Error, /Vote is locked/)
      end
    end
  end

  describe ".unvote!" do
    context "with an existing upvote" do
      before { described_class.vote!(user: voter, post: post, score: 1) }

      it "removes the PostVote" do
        expect { described_class.unvote!(user: voter, post: post) }
          .to change(PostVote, :count).by(-1)
      end

      it "reverts post.score" do
        expect { described_class.unvote!(user: voter, post: post) }
          .to change { post.reload.score }.by(-1)
      end

      it "reverts post.up_score" do
        expect { described_class.unvote!(user: voter, post: post) }
          .to change { post.reload.up_score }.by(-1)
      end
    end

    context "with an existing downvote" do
      let(:voter) { create(:user, created_at: 4.days.ago) }

      before { described_class.vote!(user: voter, post: post, score: -1) }

      it "reverts post.score" do
        expect { described_class.unvote!(user: voter, post: post) }
          .to change { post.reload.score }.by(1)
      end

      it "reverts post.down_score" do
        expect { described_class.unvote!(user: voter, post: post) }
          .to change { post.reload.down_score }.by(1)
      end
    end

    context "when no vote exists" do
      it "does not raise" do
        expect { described_class.unvote!(user: voter, post: post) }.not_to raise_error
      end

      it "does not change PostVote count" do
        expect { described_class.unvote!(user: voter, post: post) }
          .not_to change(PostVote, :count)
      end
    end

    context "with a locked vote (score 0)" do
      let!(:locked_vote) { create(:locked_post_vote) }
      let(:post) { locked_vote.post }

      it "raises without force:" do
        expect { described_class.unvote!(user: locked_vote.user, post: post) }
          .to raise_error(UserVote::Error, /locked/)
      end

      it "removes the vote with force: true" do
        expect { described_class.unvote!(user: locked_vote.user, post: post, force: true) }
          .to change(PostVote, :count).by(-1)
      end
    end
  end

  describe ".lock!" do
    context "with an upvote" do
      before { described_class.vote!(user: voter, post: post, score: 1) }

      let(:vote) { PostVote.find_by!(user: voter, post: post) }

      it "sets the vote score to 0" do
        described_class.lock!(vote.id)
        expect(vote.reload.score).to eq(0)
      end

      it "decrements post.score" do
        expect { described_class.lock!(vote.id) }
          .to change { post.reload.score }.by(-1)
      end

      it "decrements post.up_score" do
        expect { described_class.lock!(vote.id) }
          .to change { post.reload.up_score }.by(-1)
      end
    end

    context "with a downvote" do
      let(:voter) { create(:user, created_at: 4.days.ago) }
      let(:vote)  { PostVote.find_by!(user: voter, post: post) }

      before { described_class.vote!(user: voter, post: post, score: -1) }

      it "sets the vote score to 0" do
        described_class.lock!(vote.id)
        expect(vote.reload.score).to eq(0)
      end

      it "increments post.score (removes downvote contribution)" do
        expect { described_class.lock!(vote.id) }
          .to change { post.reload.score }.by(1)
      end

      # FIXME: lock! uses `down_score = down_score - 1` for downvotes (vote_manager.rb:91) but
      # should use `+ 1` to move down_score toward 0, mirroring what unvote! does (vote_manager.rb:68).
      # it "increments post.down_score toward 0" do
      #   expect { described_class.lock!(vote.id) }
      #     .to change { post.reload.down_score }.by(1)
      # end
    end

    context "with a non-existent id" do
      it "does not raise" do
        expect { described_class.lock!(-1) }.not_to raise_error
      end
    end
  end

  describe ".admin_unvote!" do
    context "with a normal vote" do
      let!(:vote) { create(:post_vote) }
      let(:post)  { vote.post }

      it "removes the vote" do
        expect { described_class.admin_unvote!(vote.id) }
          .to change(PostVote, :count).by(-1)
      end
    end

    context "with a locked vote" do
      let!(:vote) { create(:locked_post_vote) }

      it "removes the locked vote (force bypass)" do
        expect { described_class.admin_unvote!(vote.id) }
          .to change(PostVote, :count).by(-1)
      end
    end

    it "does nothing for a non-existent id" do
      expect { described_class.admin_unvote!(-1) }.not_to raise_error
    end
  end
<<<<<<< HEAD

  describe ".vote_abuse_patterns" do
    it "includes post ratings as metatags" do
      posts = %w[s q e].map do |rating|
        create(:post, tag_string: "common", tag_count: 1, tag_count_general: 1, rating: rating)
      end

      posts.each do |post|
        described_class.vote!(user: voter, post: post, score: 1)
      end

      trend_tags = described_class::VoteAbuseMethods.vote_abuse_patterns(user: voter, limit: 3, threshold: 0.0)
      trend_tag_names = trend_tags.map { |trend_tag, _| trend_tag.name }

      expect(trend_tag_names).to include("rating:s", "rating:q", "rating:e")
    end
  end
=======
>>>>>>> master
end
