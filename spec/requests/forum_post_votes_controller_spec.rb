# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumPostVotesController do
  let(:posting_user) { create(:user) }
  let(:user2) { create(:user) }
  let(:forum_post) do
    CurrentUser.scoped posting_user do
      create(:forum_topic, original_post_attributes: { body: "alias", creator: posting_user }).original_post
    end
  end

  before do
    CurrentUser.user = posting_user
    CurrentUser.ip_addr = "127.0.0.1"
  end

  context "without a tag change request" do
    it "prevents voting" do
      post_auth forum_post_votes_path(forum_post_id: forum_post.id, format: :json), posting_user, params: { forum_post_vote: { score: 1 } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with an already accepted tag change request" do
    it "prevents voting" do
      @alias = create(:active_tag_alias, forum_post: forum_post)
      post_auth forum_post_votes_path(forum_post_id: forum_post.id, format: :json), posting_user, params: { forum_post_vote: { score: 1 } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "with a pending tag change request" do
    before do
      CurrentUser.scoped posting_user do
        create(:pending_tag_alias, forum_post: forum_post)
      end
    end

    it "allows voting" do
      expect do
        post_auth forum_post_votes_path(forum_post_id: forum_post.id, format: :json), user2, params: { forum_post_vote: { score: 1 } }
      end.to change(ForumPostVote, :count).by(1)
      expect(response).to have_http_status(:success)
    end

    it "doesn't allow voting for the user who created the request" do
      expect do
        post_auth forum_post_votes_path(forum_post_id: forum_post.id, format: :json), posting_user, params: { forum_post_vote: { score: 1 } }
      end.not_to change(ForumPostVote, :count)
      expect(response).to have_http_status(:forbidden)
    end

    context "when deleting" do
      before do
        CurrentUser.scoped(user2) do
          forum_post.votes.create(score: 1)
        end
      end

      it "allows removal" do
        expect do
          delete_auth forum_post_votes_path(forum_post_id: forum_post.id, format: :json), user2
          expect(response).to have_http_status(:success)
        end.to change(ForumPostVote, :count).by(-1)
        expect(ForumPostVote.count).to be(0)
      end
    end
  end
end
