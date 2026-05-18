# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::Post::DisapprovalsController do
  include_context "as admin"

  let(:approver) { create(:approver_user) }
  let(:member)   { create(:user) }
  let(:the_post) { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /moderator/post/disapprovals
  # ---------------------------------------------------------------------------

  describe "GET /moderator/post/disapprovals" do
    it "redirects anonymous to the login page" do
      get moderator_post_disapprovals_path
      expect(response).to redirect_to(new_session_path(url: moderator_post_disapprovals_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get moderator_post_disapprovals_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an approver" do
      sign_in_as approver
      get moderator_post_disapprovals_path
      expect(response).to have_http_status(:ok)
    end

    context "as approver requesting JSON" do
      before { sign_in_as approver }

      it "returns a JSON array" do
        create(:post_disapproval, user: approver, post: the_post)
        get moderator_post_disapprovals_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      it "filters by post_id search param" do
        other_post = create(:post)
        target = create(:post_disapproval, user: approver, post: the_post)
        other_disapproval = create(:post_disapproval, post: other_post)
        get moderator_post_disapprovals_path(format: :json), params: { search: { post_id: the_post.id } }
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(target.id)
        expect(ids).not_to include(other_disapproval.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/disapprovals
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/disapprovals" do
    let(:valid_params) do
      { post_disapproval: { post_id: the_post.id, reason: "other", message: "" } }
    end

    it "redirects anonymous to the login page" do
      post moderator_post_disapprovals_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post moderator_post_disapprovals_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an approver" do
      before { sign_in_as approver }

      it "creates a disapproval and redirects to the post for HTML" do
        expect do
          post moderator_post_disapprovals_path, params: valid_params
        end.to change(PostDisapproval, :count).by(1)
        expect(response).to redirect_to(post_path(id: the_post.id))
      end

      it "creates a disapproval and returns JSON" do
        post moderator_post_disapprovals_path(format: :json), params: valid_params
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["id"]).to be_present
        expect(body["reason"]).to eq("other")
      end

      it "is idempotent — a second POST for the same user and post does not create a duplicate" do
        post moderator_post_disapprovals_path, params: valid_params
        expect do
          post moderator_post_disapprovals_path, params: { post_disapproval: { post_id: the_post.id, reason: "borderline_quality", message: "updated" } }
        end.not_to change(PostDisapproval, :count)
      end

      it "updates reason and message on an existing record" do
        post moderator_post_disapprovals_path, params: valid_params
        post moderator_post_disapprovals_path, params: { post_disapproval: { post_id: the_post.id, reason: "borderline_quality", message: "updated note" } }
        record = PostDisapproval.find_by!(user: approver, post: the_post)
        expect(record.reason).to eq("borderline_quality")
        expect(record.message).to eq("updated note")
      end
    end
  end
end
