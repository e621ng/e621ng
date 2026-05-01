# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagsController do
  include_context "as admin"

  # Members older than 3 days bypass the :REJ_NEWBIE throttle gate on post_flag creation.
  let(:member)      { create(:user, created_at: 4.days.ago) }
  let(:janitor)     { create(:janitor_user) }
  let(:admin)       { create(:admin_user) }
  let(:post_record) { create(:post) }
  let(:flag_reason) { create(:post_flag_reason) }

  # belongs_to_creator reads CurrentUser; swap to member so the flag's creator is correct.
  let(:post_flag) do
    CurrentUser.scoped(member) { create(:post_flag, reason_name: flag_reason.name, post: post_record) }
  end

  # ---------------------------------------------------------------------------
  # GET /post_flags — index
  # ---------------------------------------------------------------------------

  describe "GET /post_flags" do
    it "returns 200 for anonymous" do
      get post_flags_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get post_flags_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get post_flags_path
      expect(response).to have_http_status(:ok)
    end

    it "filters by post_id" do
      post_flag
      other_post = create(:post)
      get post_flags_path(search: { post_id: other_post.id }, format: :json)
      expect(response.parsed_body).to be_empty
    end

    it "filters by is_resolved=false" do
      post_flag
      get post_flags_path(search: { is_resolved: "false" }, format: :json)
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(post_flag.id)
    end

    it "filters by type=flag (excludes deletion flags)" do
      post_flag
      get post_flags_path(search: { type: "flag" }, format: :json)
      expect(response.parsed_body).to all(include("type" => "flag"))
    end

    it "accepts the note search param as a janitor without error" do
      sign_in_as janitor
      get post_flags_path(search: { note: "anything" })
      expect(response).to have_http_status(:ok)
    end

    it "accepts the ip_addr search param as an admin without error" do
      sign_in_as admin
      get post_flags_path(search: { ip_addr: "127.0.0.1" })
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_flags/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /post_flags/:id" do
    # post_flag_path conflicts with the nested resource :flag under :posts, so use URL strings.
    it "redirects HTML to the index filtered by the flag id" do
      get "/post_flags/#{post_flag.id}"
      expect(response).to redirect_to(post_flags_path(search: { id: post_flag.id }))
    end

    it "returns 200 JSON with flag attributes" do
      get "/post_flags/#{post_flag.id}.json"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => post_flag.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_flags/new — new
  # ---------------------------------------------------------------------------

  describe "GET /post_flags/new" do
    it "redirects anonymous HTML to the login page" do
      get new_post_flag_path
      expect(response).to redirect_to(new_session_path(url: new_post_flag_path))
    end

    it "returns 403 for anonymous JSON" do
      get new_post_flag_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get new_post_flag_path, params: { post_flag: { post_id: post_record.id } }
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_flags — create
  # ---------------------------------------------------------------------------

  describe "POST /post_flags" do
    let(:flaggable_post) { create(:post) }
    let(:flag_reason)    { create(:post_flag_reason) }
    let(:valid_params)   { { post_flag: { post_id: flaggable_post.id, reason_name: flag_reason.name } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post post_flags_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post post_flags_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a flag and redirects to the post" do
        expect { post post_flags_path, params: valid_params }.to change(PostFlag, :count).by(1)
        expect(response).to redirect_to(post_path(id: flaggable_post.id))
      end

      it "does not create a flag with an unknown reason and re-renders the form" do
        expect do
          post post_flags_path, params: { post_flag: { post_id: flaggable_post.id, reason_name: "not_a_real_reason" } }
        end.not_to change(PostFlag, :count)
        expect(response).to have_http_status(:ok)
      end

      it "returns 422 for JSON with an invalid reason" do
        post post_flags_path(format: :json), params: { post_flag: { post_id: flaggable_post.id, reason_name: "not_a_real_reason" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /posts/:post_id/flag — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /posts/:post_id/flag" do
    before do
      post_flag
      post_record.update_columns(is_flagged: true)
    end

    it "redirects anonymous HTML to the login page" do
      delete "/posts/#{post_record.id}/flag"
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      delete "/posts/#{post_record.id}/flag"
      expect(response).to have_http_status(:forbidden)
    end

    it "unflags the post for a janitor" do
      sign_in_as janitor
      expect { delete "/posts/#{post_record.id}/flag" }.to change { post_record.reload.is_flagged }.from(true).to(false)
    end

    context "with approval=approve on a pending post" do
      let(:post_record) { create(:pending_post) }

      it "also approves the post" do
        sign_in_as janitor
        delete "/posts/#{post_record.id}/flag", params: { approval: "approve" }
        expect(post_record.reload.is_pending).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_flags/:id/clear_note — clear_note
  # ---------------------------------------------------------------------------

  describe "POST /post_flags/:id/clear_note" do
    it "redirects anonymous HTML to the login page" do
      post clear_note_post_flag_path(post_flag)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      post clear_note_post_flag_path(post_flag)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "clears the note, redirects to the index, and sets a flash notice" do
        post clear_note_post_flag_path(post_flag)
        expect(response).to redirect_to(post_flags_path)
        expect(flash[:notice]).to eq("Note cleared")
        expect(post_flag.reload.note).to be_nil
      end

      it "returns 200 JSON with the updated flag" do
        post clear_note_post_flag_path(post_flag, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("id" => post_flag.id)
      end
    end
  end
end
