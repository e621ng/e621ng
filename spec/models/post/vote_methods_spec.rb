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
  end
end
