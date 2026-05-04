# frozen_string_literal: true

require "rails_helper"

# hide_comment    POST   /comments/:id/hide(.:format)     comments#hide
# unhide_comment  POST   /comments/:id/unhide(.:format)   comments#unhide
# warning_comment POST   /comments/:id/warning(.:format)  comments#warning
# search_comments GET    /comments/search(.:format)       comments#search
# comments        GET    /comments(.:format)              comments#index
#                 POST   /comments(.:format)              comments#create
# new_comment     GET    /comments/new(.:format)          comments#new
# edit_comment    GET    /comments/:id/edit(.:format)     comments#edit
# comment         GET    /comments/:id(.:format)          comments#show
#                 PATCH  /comments/:id(.:format)          comments#update
#                 PUT    /comments/:id(.:format)          comments#update
#                 DELETE /comments/:id(.:format)          comments#destroy
# comments_post   GET    /posts/:id/comments(.:format)    comments#for_post

RSpec.describe CommentsController do
  let(:member)       { RSpec::Mocks.with_temporary_scope { create(:user) } }
  let(:other_member) { create(:user) }
  let(:janitor)      { create(:janitor_user) }
  let(:moderator)    { create(:moderator_user) }
  let(:admin)        { create(:admin_user) }

  let(:comment)        { CurrentUser.scoped(member) { create(:comment) } }
  let(:hidden_comment) { CurrentUser.scoped(member) { create(:hidden_comment) } }

  around { |example| CurrentUser.scoped(member) { example.run } }

  # ---------------------------------------------------------------------------
  # GET /comments — index by comment (default)
  # ---------------------------------------------------------------------------

  describe "GET /comments" do
    it "returns 200 for anonymous" do
      comment
      get comments_path
      expect(response).to have_http_status(:ok)
    end

    it "returns comment records as JSON" do
      comment
      get comments_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to include(comment.id)
    end

    it "filters by body_matches" do
      comment
      other = CurrentUser.scoped(member) { create(:comment, body: "uniqueterm") }
      get comments_path(format: :json, search: { body_matches: "uniqueterm" })
      expect(response.parsed_body.pluck("id")).to include(other.id)
      expect(response.parsed_body.pluck("id")).not_to include(comment.id)
    end

    describe "is_hidden search param" do
      it "returns 403 for anonymous — param is not permitted" do
        get comments_path(format: :json, search: { is_hidden: "true" })
        expect(response).to have_http_status(:forbidden)
      end

      it "is accepted for moderators without raising an error" do
        sign_in_as moderator
        get comments_path(format: :json, search: { is_hidden: "true" })
        expect(response).to have_http_status(:ok)
      end
    end

    describe "created_at search param" do
      it "returns 422 for invalid created_at value in HTML format" do
        get comments_path(search: { created_at: "999999999999999999999" })
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 for invalid created_at value in JSON format" do
        get comments_path(format: :json, search: { created_at: "999999999999999999999" })
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments?group_by=post — index by post
  # ---------------------------------------------------------------------------

  describe "GET /comments?group_by=post" do
    it "returns 200" do
      comment
      get comments_path(group_by: "post")
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/search
  # ---------------------------------------------------------------------------

  describe "GET /comments/search" do
    it "returns 200" do
      get search_comments_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /comments/:id" do
    it "returns 200 for a visible comment" do
      get comment_path(comment)
      expect(response).to have_http_status(:ok)
    end

    it "redirects anonymous to login for a hidden comment" do
      get comment_path(hidden_comment)
      expect(response).to have_http_status(:redirect)
    end

    it "returns 403 for a hidden comment when viewed by another member" do
      sign_in_as other_member
      get comment_path(hidden_comment)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a hidden comment when the viewer is a moderator" do
      sign_in_as moderator
      get comment_path(hidden_comment)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a non-existent comment" do
      get comment_path(-1)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id/comments — for_post
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/comments" do
    it "returns JSON with an html key" do
      get comments_post_path(comment.post, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("html")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/new
  # ---------------------------------------------------------------------------

  describe "GET /comments/new" do
    it "redirects anonymous to login (member_only)" do
      get new_comment_path
      expect(response).to have_http_status(:redirect)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_comment_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /comments/:id/edit
  # ---------------------------------------------------------------------------

  describe "GET /comments/:id/edit" do
    it "returns 200 for the creator" do
      sign_in_as member
      get edit_comment_path(comment)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_comment_path(comment)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a non-creator member" do
      sign_in_as other_member
      get edit_comment_path(comment)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous to login (member_only)" do
      get edit_comment_path(comment)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comments — create
  # ---------------------------------------------------------------------------

  describe "POST /comments" do
    let(:post_record) { create(:post) }

    it "redirects anonymous to login (member_only)" do
      post comments_path, params: { comment: { body: "test", post_id: post_record.id } }
      expect(response).to have_http_status(:redirect)
    end

    it "creates a comment and sets flash notice for valid params" do
      expect do
        sign_in_as member
        post comments_path, params: { comment: { body: "new comment", post_id: post_record.id } }
      end.to change(Comment, :count).by(1)
      expect(flash[:notice]).to eq("Comment posted")
    end

    it "does not create a comment and sets flash with error for empty body" do
      expect do
        sign_in_as member
        post comments_path, params: { comment: { body: "", post_id: post_record.id } }
      end.not_to change(Comment, :count)
      expect(flash[:notice]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /comments/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /comments/:id" do
    it "redirects anonymous to login (member_only)" do
      patch comment_path(comment), params: { comment: { body: "updated" } }
      expect(response).to have_http_status(:redirect)
    end

    it "updates the body for the creator and redirects to the post" do
      sign_in_as member
      patch comment_path(comment), params: { comment: { body: "updated body" } }
      expect(comment.reload.body).to eq("updated body")
      expect(response).to redirect_to(post_path(comment.post_id))
    end

    it "returns 403 for a non-creator member" do
      sign_in_as other_member
      patch comment_path(comment), params: { comment: { body: "hacked" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /comments/:id — destroy (admin_only)
  # ---------------------------------------------------------------------------

  describe "DELETE /comments/:id" do
    it "destroys the comment for an admin" do
      comment
      sign_in_as admin
      expect { delete comment_path(comment) }.to change(Comment, :count).by(-1)
    end

    it "returns 403 for a moderator (admin_only)" do
      sign_in_as moderator
      delete comment_path(comment)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member (admin_only)" do
      sign_in_as member
      delete comment_path(comment)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comments/:id/hide
  # ---------------------------------------------------------------------------

  describe "POST /comments/:id/hide" do
    it "hides the comment for a moderator" do
      sign_in_as moderator
      post hide_comment_path(comment)
      expect(comment.reload.is_hidden).to be(true)
    end

    it "hides the comment for the creator" do
      sign_in_as member
      post hide_comment_path(comment)
      expect(comment.reload.is_hidden).to be(true)
    end

    it "returns 403 for an unrelated member" do
      sign_in_as other_member
      post hide_comment_path(comment)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous to login (member_only)" do
      post hide_comment_path(comment)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comments/:id/unhide (moderator_only)
  # ---------------------------------------------------------------------------

  describe "POST /comments/:id/unhide" do
    it "unhides the comment for a moderator" do
      sign_in_as moderator
      post unhide_comment_path(hidden_comment)
      expect(hidden_comment.reload.is_hidden).to be(false)
    end

    it "returns 403 for a member (moderator_only)" do
      sign_in_as member
      post unhide_comment_path(hidden_comment)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /comments/:id/warning (moderator_only)
  # ---------------------------------------------------------------------------

  describe "POST /comments/:id/warning" do
    it "applies a warning and returns JSON with an html key" do
      sign_in_as moderator
      post warning_comment_path(comment), params: { record_type: "warning" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("html")
      expect(comment.reload.warning_type).to eq("warning")
    end

    it "removes a warning when record_type is unmark" do
      CurrentUser.scoped(moderator) { comment.user_warned!("warning", moderator) }
      sign_in_as moderator
      post warning_comment_path(comment), params: { record_type: "unmark" }
      expect(comment.reload.warning_type).to be_nil
    end

    it "returns 403 for a member (moderator_only)" do
      sign_in_as member
      post warning_comment_path(comment), params: { record_type: "warning" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:comments_disabled?).and_return(true)
    end

    it "denies a non-staff member when comments are locked down" do
      sign_in_as member
      post comments_path, params: { comment: { body: "test", post_id: create(:post).id } }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (moderator) through when comments are locked down" do
      post_record = create(:post)
      sign_in_as moderator
      post comments_path, params: { comment: { body: "test", post_id: post_record.id } }
      expect(response).not_to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # comment_params filtering
  # ---------------------------------------------------------------------------

  describe "comment_params filtering" do
    let(:post_record) { create(:post) }

    describe "is_sticky" do
      it "raises 403 for a regular member (unpermitted parameter)" do
        sign_in_as member
        post comments_path, params: { comment: { body: "test", post_id: post_record.id, is_sticky: true } }
        expect(response).to have_http_status(:forbidden)
      end

      it "is accepted for a janitor" do
        sign_in_as janitor
        post comments_path, params: { comment: { body: "test", post_id: post_record.id, is_sticky: true } }
        expect(Comment.last.is_sticky).to be(true)
      end
    end

    describe "is_hidden" do
      it "raises 403 for a regular member (unpermitted parameter)" do
        sign_in_as member
        post comments_path, params: { comment: { body: "test", post_id: post_record.id, is_hidden: true } }
        expect(response).to have_http_status(:forbidden)
      end

      it "is accepted for a moderator" do
        sign_in_as moderator
        post comments_path, params: { comment: { body: "test", post_id: post_record.id, is_hidden: true } }
        expect(Comment.last.is_hidden).to be(true)
      end
    end
  end
end
