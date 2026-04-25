# frozen_string_literal: true

require "rails_helper"

RSpec.describe VoteManager do
  include_context "as admin"

  # Comment votes require users to be 3+ days old. Admins bypass this via
  # general_bypass_throttle? (is_privileged?), so we use the admin set by the
  # shared context as the voter throughout this file.
  let(:voter) { CurrentUser.user }
  let(:comment) do
    c = create(:comment)
    # Ensure the comment's creator is someone other than the voter so that
    # validate_comment_can_be_voted does not reject the vote.
    c.update_columns(creator_id: create(:user).id)
    c
  end

  describe ".comment_vote!" do
    it "raises for an invalid score of 0" do
      expect { described_class.comment_vote!(user: voter, comment: comment, score: 0) }
        .to raise_error(UserVote::Error, /Invalid vote/)
    end

    it "raises when the user is not a member" do
      non_member = create(:user)
      allow(non_member).to receive(:is_member?).and_return(false)
      expect { described_class.comment_vote!(user: non_member, comment: comment, score: 1) }
        .to raise_error(UserVote::Error, /permission/)
    end

    context "when the post has comments locked" do
      let(:comment) do
        c = create(:comment, post: create(:post, is_comment_locked: true))
        c.update_columns(creator_id: create(:user).id)
        c
      end

      it "raises" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: 1) }
          .to raise_error(UserVote::Error, /locked/)
      end
    end

    context "when the post has comments disabled" do
      let(:comment) do
        c = create(:comment, post: create(:post, is_comment_disabled: true))
        c.update_columns(creator_id: create(:user).id)
        c
      end

      it "raises" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: 1) }
          .to raise_error(UserVote::Error, /disabled/)
      end
    end

    context "with an upvote" do
      subject(:cast_upvote) { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

      it "creates a CommentVote" do
        expect { cast_upvote }.to change(CommentVote, :count).by(1)
      end

      it "increments comment.score" do
        expect { cast_upvote }.to change { comment.reload.score }.by(1)
      end

      it "returns the created CommentVote" do
        expect(cast_upvote).to be_a(CommentVote)
      end
    end

    context "with a downvote" do
      subject(:cast_downvote) { described_class.comment_vote!(user: voter, comment: comment, score: -1) }

      it "creates a CommentVote" do
        expect { cast_downvote }.to change(CommentVote, :count).by(1)
      end

      it "decrements comment.score" do
        expect { cast_downvote }.to change { comment.reload.score }.by(-1)
      end
    end

    context "when re-voting with the same score" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

      it "returns :need_unvote" do
        expect(described_class.comment_vote!(user: voter, comment: comment, score: 1)).to eq(:need_unvote)
      end

      it "does not create another CommentVote" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: 1) }
          .not_to change(CommentVote, :count)
      end
    end

    context "when flipping an upvote to a downvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

      it "changes comment.score by -2" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: -1) }
          .to change { comment.reload.score }.by(-2)
      end
    end

    context "when flipping a downvote to an upvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: -1) }

      it "changes comment.score by +2" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: 1) }
          .to change { comment.reload.score }.by(2)
      end
    end

    context "when the existing vote is locked (score 0)" do
      before do
        described_class.comment_vote!(user: voter, comment: comment, score: 1)
        v = CommentVote.find_by!(user: voter, comment: comment)
        described_class.comment_lock!(v.id)
      end

      it "raises Vote is locked" do
        expect { described_class.comment_vote!(user: voter, comment: comment, score: 1) }
          .to raise_error(UserVote::Error, /Vote is locked/)
      end
    end
  end

  describe ".comment_unvote!" do
    context "with an existing upvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

      it "removes the CommentVote" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }
          .to change(CommentVote, :count).by(-1)
      end

      it "reverts comment.score" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }
          .to change { comment.reload.score }.by(-1)
      end
    end

    context "with an existing downvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: -1) }

      it "reverts comment.score" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }
          .to change { comment.reload.score }.by(1)
      end
    end

    context "when no vote exists" do
      it "does not raise" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }.not_to raise_error
      end

      it "does not change CommentVote count" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }
          .not_to change(CommentVote, :count)
      end
    end

    context "with a locked vote (score 0)" do
      before do
        described_class.comment_vote!(user: voter, comment: comment, score: 1)
        v = CommentVote.find_by!(user: voter, comment: comment)
        described_class.comment_lock!(v.id)
      end

      it "raises without force:" do
        expect { described_class.comment_unvote!(user: voter, comment: comment) }
          .to raise_error(UserVote::Error, /locked/)
      end

      it "removes the vote with force: true" do
        expect { described_class.comment_unvote!(user: voter, comment: comment, force: true) }
          .to change(CommentVote, :count).by(-1)
      end
    end
  end

  describe ".comment_lock!" do
    context "with an upvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

      let(:vote) { CommentVote.find_by!(user: voter, comment: comment) }

      it "sets the vote score to 0" do
        described_class.comment_lock!(vote.id)
        expect(vote.reload.score).to eq(0)
      end

      it "decrements comment.score" do
        expect { described_class.comment_lock!(vote.id) }
          .to change { comment.reload.score }.by(-1)
      end
    end

    context "with a downvote" do
      before { described_class.comment_vote!(user: voter, comment: comment, score: -1) }

      let(:vote) { CommentVote.find_by!(user: voter, comment: comment) }

      it "sets the vote score to 0" do
        described_class.comment_lock!(vote.id)
        expect(vote.reload.score).to eq(0)
      end

      it "increments comment.score (removes downvote contribution)" do
        expect { described_class.comment_lock!(vote.id) }
          .to change { comment.reload.score }.by(1)
      end
    end

    it "does nothing for a non-existent id" do
      expect { described_class.comment_lock!(-1) }.not_to raise_error
    end
  end

  describe ".admin_comment_unvote!" do
    before { described_class.comment_vote!(user: voter, comment: comment, score: 1) }

    let(:vote) { CommentVote.find_by!(user: voter, comment: comment) }

    it "removes the vote" do
      expect { described_class.admin_comment_unvote!(vote.id) }
        .to change(CommentVote, :count).by(-1)
    end

    it "does nothing for a non-existent id" do
      expect { described_class.admin_comment_unvote!(-1) }.not_to raise_error
    end
  end
end
