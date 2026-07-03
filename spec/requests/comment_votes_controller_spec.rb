# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentVotesController do
  include_context "as admin"

  let(:voter)     { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }
  # Creator is replaced so the voter is never the comment's creator (self-vote check)
  let(:comment_rec) do
    create(:comment).tap { |c| c.update_columns(creator_id: create(:user).id) }
  end

  # ---------------------------------------------------------------------------
  # POST /comments/:comment_id/votes — create
  # ---------------------------------------------------------------------------

  describe "POST /comments/:comment_id/votes" do
    it "returns 403 for anonymous" do
      post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a member" do
      before { sign_in_as voter }

      it "upvotes a comment and returns score JSON" do
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to include("score", "our_score")
        expect(body["our_score"]).to eq(1)
      end

      it "downvotes a comment for a user at least 3 days old" do
        voter.update_columns(created_at: 4.days.ago)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(-1)
      end

      it "returns 422 when a user under 3 days old tries to downvote" do
        voter.update_columns(created_at: 1.day.ago)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "auto-unvotes when voting the same direction twice and returns our_score 0" do
        create(:comment_vote, comment: comment_rec, user: voter, score: 1)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(0)
        expect(CommentVote.where(comment: comment_rec, user: voter)).to be_empty
      end

      it "keeps the vote when no_unvote is set and returns our_score 0" do
        create(:comment_vote, comment: comment_rec, user: voter, score: 1)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1, no_unvote: "1" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(0)
        expect(CommentVote.where(comment: comment_rec, user: voter)).to be_present
      end

      it "replaces an opposite vote" do
        voter.update_columns(created_at: 4.days.ago)
        create(:comment_vote, comment: comment_rec, user: voter, score: 1)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(-1)
      end

      it "returns 422 for an invalid score" do
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 2 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 for a non-existent comment" do
        post comment_votes_path(comment_id: 0, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 422 when attempting to re-vote a locked comment vote" do
        create(:locked_comment_vote, comment: comment_rec, user: voter)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 422 when voting on own comment" do
        comment_rec.update_columns(creator_id: voter.id)
        post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 422 when voting on a sticky comment" do
        sticky = create(:sticky_comment).tap { |c| c.update_columns(creator_id: create(:user).id) }
        post comment_votes_path(comment_id: sticky.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /comments/:comment_id/votes — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /comments/:comment_id/votes" do
    it "returns 403 for anonymous" do
      delete comment_votes_path(comment_id: comment_rec.id, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a member" do
      before { sign_in_as voter }

      it "removes an existing vote" do
        create(:comment_vote, comment: comment_rec, user: voter, score: 1)
        delete comment_votes_path(comment_id: comment_rec.id, format: :json)
        expect(response).to have_http_status(:success)
        expect(CommentVote.where(comment: comment_rec, user: voter)).to be_empty
      end

      it "succeeds silently when there is no vote to remove" do
        delete comment_votes_path(comment_id: comment_rec.id, format: :json)
        expect(response).to have_http_status(:success)
      end

      it "returns 422 when attempting to remove a locked vote" do
        create(:locked_comment_vote, comment: comment_rec, user: voter)
        delete comment_votes_path(comment_id: comment_rec.id, format: :json)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 for a non-existent comment" do
        delete comment_votes_path(comment_id: 0, format: :json)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comment_votes — index
  # ---------------------------------------------------------------------------

  describe "GET /comment_votes" do
    it "returns 403 for anonymous" do
      get "/comment_votes.json"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      get "/comment_votes"
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "returns 200 for HTML" do
        get "/comment_votes"
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON array" do
        get "/comment_votes.json"
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      it "filters results by comment_id" do
        other_comment = create(:comment).tap { |c| c.update_columns(creator_id: create(:user).id) }
        matching      = create(:comment_vote, comment: comment_rec)
        other_vote    = create(:comment_vote, comment: other_comment)

        get "/comment_votes.json", params: { search: { comment_id: comment_rec.id } }
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(matching.id)
        expect(ids).not_to include(other_vote.id)
      end

      it "filters results by score" do
        aged_voter = create(:user, created_at: 4.days.ago)
        upvote     = create(:comment_vote, comment: comment_rec, user: aged_voter, score: 1)
        downvote   = create(:down_comment_vote, comment: create(:comment).tap { |c| c.update_columns(creator_id: create(:user).id) }, user: aged_voter)

        get "/comment_votes.json", params: { search: { user_id: aged_voter.id, score: "1" } }
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(upvote.id)
        expect(ids).not_to include(downvote.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comment_votes/lock — lock
  # ---------------------------------------------------------------------------

  describe "POST /comment_votes/lock" do
    it "returns 403 for anonymous" do
      post lock_comment_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      post lock_comment_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "locks the specified votes, zeroing their score" do
        vote = create(:comment_vote, comment: comment_rec, user: create(:user), score: 1)
        post lock_comment_votes_path(format: :json), params: { ids: vote.id.to_s }
        expect(response).to have_http_status(:success)
        expect(vote.reload.score).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comment_votes/delete — delete
  # ---------------------------------------------------------------------------

  describe "POST /comment_votes/delete" do
    it "returns 403 for anonymous" do
      post delete_comment_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      post delete_comment_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      post delete_comment_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "force-deletes the specified votes" do
        vote = create(:comment_vote, comment: comment_rec, user: create(:user), score: 1)
        vote_id = vote.id
        post delete_comment_votes_path(format: :json), params: { ids: vote_id.to_s }
        expect(response).to have_http_status(:success)
        expect(CommentVote.find_by(id: vote_id)).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:votes_disabled?).and_return(true)
    end

    it "returns 403 for a member when votes are disabled" do
      sign_in_as voter
      post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a moderator through when votes are disabled" do
      sign_in_as moderator
      post comment_votes_path(comment_id: comment_rec.id, format: :json), params: { score: 1 }
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
