# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "VoteMethods" do
    describe "#own_vote" do
      it "returns nil when the user has not voted" do
        user = create(:user)
        post = create(:post)
        expect(post.own_vote(user)).to be_nil
      end

      it "returns the PostVote record when the user has voted" do
        user = create(:user)
        post = create(:post)
        vote = PostVote.create!(post: post, user: user, score: 1)
        expect(post.own_vote(user)).to eq(vote)
      end

      it "returns nil when user is nil" do
        post = create(:post)
        expect(post.own_vote(nil)).to be_nil
      end
    end

    describe "#vote_by" do
      it "returns 0 when the user has not voted" do
        user = create(:user)
        post = create(:post)
        expect(post.vote_by(user.id)).to eq(0)
      end

      it "returns the score when the user has upvoted" do
        user = create(:user)
        post = create(:post)
        PostVote.create!(post: post, user: user, score: 1)
        expect(post.vote_by(user.id)).to eq(1)
      end

      it "returns the score when the user has downvoted" do
        vote = create(:down_post_vote)
        expect(vote.post.vote_by(vote.user_id)).to eq(-1)
      end

      it "returns 0 for a locked vote (score: 0)" do
        user = create(:user)
        post = create(:post)
        PostVote.create!(post: post, user: user, score: 0)
        expect(post.vote_by(user.id)).to eq(0)
      end

      it "returns 0 for a blank user id" do
        post = create(:post)
        expect(post.vote_by(nil)).to eq(0)
      end

      it "caches the DB result so a second call does not hit the database" do
        user = create(:user)
        post = create(:post)
        PostVote.create!(post: post, user: user, score: 1)
        post.vote_by(user.id) # primes cache
        allow(PostVote).to receive(:where)
        post.vote_by(user.id)
        expect(PostVote).not_to have_received(:where)
      end

      it "uses the preloaded cache instead of hitting the database" do
        post = create(:post)
        post.preset_vote_by(42, 1)
        allow(PostVote).to receive(:where)
        expect(post.vote_by(42)).to eq(1)
        expect(PostVote).not_to have_received(:where)
      end

      it "uses a preloaded 0 instead of hitting the database" do
        post = create(:post)
        post.preset_vote_by(42, 0)
        allow(PostVote).to receive(:where)
        expect(post.vote_by(42)).to eq(0)
        expect(PostVote).not_to have_received(:where)
      end
    end

    describe ".preload_vote_by!" do
      it "primes the cache with the user's vote scores for the given posts" do
        user = create(:user, created_at: 4.days.ago)
        upvoted = create(:post)
        downvoted = create(:post)
        unvoted = create(:post)
        PostVote.create!(post: upvoted, user: user, score: 1)
        PostVote.create!(post: downvoted, user: user, score: -1)

        Post.preload_vote_by!([upvoted, downvoted, unvoted], user.id)
        expect(upvoted.vote_by(user.id)).to eq(1)
        expect(downvoted.vote_by(user.id)).to eq(-1)
        expect(unvoted.vote_by(user.id)).to eq(0)
      end

      it "is a no-op for a blank user id" do
        post = create(:post)
        expect { Post.preload_vote_by!([post], nil) }.not_to(change { post.instance_variable_get(:@vote_by_cache) })
      end

      it "is a no-op for an empty post list" do
        expect { Post.preload_vote_by!([], 1) }.not_to raise_error
      end

      it "accepts a single post" do
        user = create(:user)
        post = create(:post)
        PostVote.create!(post: post, user: user, score: 1)
        Post.preload_vote_by!(post, user.id)
        expect(post.vote_by(user.id)).to eq(1)
      end
    end

    describe "#compute_hotness" do
      let(:divisor) { Post::HOTNESS_TIME_DIVISOR }

      it "adds exactly 1.0 for a 10x score increase" do
        post = create(:post)
        post.update_columns(score: 100)
        base = post.compute_hotness
        post.update_columns(score: 1000)
        expect(post.compute_hotness - base).to be_within(1e-9).of(1.0)
      end

      it "advances by 86400 / HOTNESS_TIME_DIVISOR for one day of created_at" do
        earlier = create(:post)
        later = create(:post)
        earlier.update_columns(score: 5, created_at: 2.days.ago)
        later.update_columns(score: 5, created_at: 1.day.ago)
        expect(later.compute_hotness - earlier.compute_hotness).to be_within(1e-6).of(86_400.0 / divisor)
      end

      it "yields the pure time term for score 0" do
        post = create(:post)
        post.update_columns(score: 0)
        expect(post.compute_hotness).to be_within(1e-9).of(post.created_at.to_f / divisor)
      end

      it "subtracts log10(|score|) from the time term for a negative score" do
        post = create(:post)
        post.update_columns(score: -100)
        expected = (post.created_at.to_f / divisor) - Math.log10(100)
        expect(post.compute_hotness).to be_within(1e-9).of(expected)
      end

      it "ranks a years-old high-score post below a modest fresh post" do
        old_great = create(:post)
        fresh = create(:post)
        old_great.update_columns(score: 30_000, created_at: 3.years.ago)
        fresh.update_columns(score: 20, created_at: 1.hour.ago)
        expect(fresh.compute_hotness).to be > old_great.compute_hotness
      end
    end

    describe "#update_hotness!" do
      it "persists the computed hotness to the column" do
        post = create(:post)
        post.update_columns(score: 42)
        post.update_hotness!
        expect(post.reload.hotness).to be_within(1e-9).of(post.compute_hotness)
      end
    end
  end
end
