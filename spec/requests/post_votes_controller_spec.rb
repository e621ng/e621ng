# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVotesController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:voter)     { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }
  let(:post_rec)  { create(:post) }

  # ---------------------------------------------------------------------------
  # POST /posts/:post_id/votes — create
  # ---------------------------------------------------------------------------

  describe "POST /posts/:post_id/votes" do
    it "returns 403 for anonymous" do
      post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a member" do
      before { sign_in_as voter }

      it "upvotes a post and returns score JSON" do
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to include("score", "up", "down", "our_score")
        expect(body["our_score"]).to eq(1)
      end

      it "downvotes a post for a user at least 3 days old" do
        voter.update_columns(created_at: 4.days.ago)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(-1)
      end

      it "returns 422 when a user under 3 days old tries to downvote" do
        voter.update_columns(created_at: 1.day.ago)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "auto-unvotes when voting the same direction twice and returns our_score 0" do
        create(:post_vote, post: post_rec, user: voter, score: 1)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(0)
        expect(PostVote.where(post: post_rec, user: voter)).to be_empty
      end

      it "keeps the vote when no_unvote is set and returns our_score 0" do
        create(:post_vote, post: post_rec, user: voter, score: 1)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1, no_unvote: "1" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(0)
        expect(PostVote.where(post: post_rec, user: voter)).to be_present
      end

      it "replaces an opposite vote" do
        voter.update_columns(created_at: 4.days.ago)
        create(:post_vote, post: post_rec, user: voter, score: 1)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: -1 }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["our_score"]).to eq(-1)
      end

      it "returns 422 for an invalid score" do
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 2 }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 for a non-existent post" do
        post post_votes_path(post_id: 0, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 422 when attempting to re-vote a locked vote" do
        create(:locked_post_vote, post: post_rec, user: voter)
        post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /posts/:post_id/votes — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /posts/:post_id/votes" do
    it "returns 403 for anonymous" do
      delete post_votes_path(post_id: post_rec.id, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a member" do
      before { sign_in_as voter }

      it "removes an existing vote" do
        create(:post_vote, post: post_rec, user: voter, score: 1)
        delete post_votes_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:success)
        expect(PostVote.where(post: post_rec, user: voter)).to be_empty
      end

      it "succeeds silently when there is no vote to remove" do
        delete post_votes_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:success)
      end

      it "returns 422 when attempting to remove a locked vote" do
        create(:locked_post_vote, post: post_rec, user: voter)
        delete post_votes_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 404 for a non-existent post" do
        delete post_votes_path(post_id: 0, format: :json)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_votes — index
  # ---------------------------------------------------------------------------

  describe "GET /post_votes" do
    it "returns 403 for anonymous" do
      get index_post_votes_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      get index_post_votes_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "returns 200 for HTML" do
        get index_post_votes_path
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON array" do
        get index_post_votes_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      it "filters results by post_id" do
        other_post    = create(:post)
        matching      = create(:post_vote, post: post_rec)
        other_vote    = create(:post_vote, post: other_post)

        get index_post_votes_path(format: :json), params: { search: { post_id: post_rec.id } }
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(matching.id)
        expect(ids).not_to include(other_vote.id)
      end

      it "filters results by score" do
        # score filter only activates when a complex param (user_id, post_id, etc.) is also present
        aged_voter = create(:user, created_at: 4.days.ago)
        upvote     = create(:post_vote, post: post_rec, user: aged_voter, score: 1)
        downvote   = create(:down_post_vote, post: create(:post), user: aged_voter)

        get index_post_votes_path(format: :json), params: { search: { user_id: aged_voter.id, score: "1" } }
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(upvote.id)
        expect(ids).not_to include(downvote.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_votes/lock — lock
  # ---------------------------------------------------------------------------

  describe "POST /post_votes/lock" do
    it "returns 403 for anonymous" do
      post lock_index_post_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      post lock_index_post_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "locks the specified votes, zeroing their score" do
        vote = create(:post_vote, post: post_rec, user: create(:user), score: 1)
        post lock_index_post_votes_path(format: :json), params: { ids: vote.id.to_s }
        expect(response).to have_http_status(:success)
        expect(vote.reload.score).to eq(0)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_votes/delete — delete
  # ---------------------------------------------------------------------------

  describe "POST /post_votes/delete" do
    it "returns 403 for anonymous" do
      post delete_index_post_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as voter
      post delete_index_post_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      post delete_index_post_votes_path(format: :json), params: { ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "force-deletes the specified votes" do
        vote = create(:post_vote, post: post_rec, user: create(:user), score: 1)
        vote_id = vote.id
        post delete_index_post_votes_path(format: :json), params: { ids: vote_id.to_s }
        expect(response).to have_http_status(:success)
        expect(PostVote.find_by(id: vote_id)).to be_nil
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
      post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a moderator through when votes are disabled" do
      sign_in_as moderator
      post post_votes_path(post_id: post_rec.id, format: :json), params: { score: 1 }
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
