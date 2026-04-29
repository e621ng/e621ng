# frozen_string_literal: true

require "rails_helper"

RSpec.describe TakedownsController do
  include_context "as admin"

  let(:member)   { create(:user) }
  let(:bd_staff) { create(:bd_staff_user) }
  # Source must be non-nil: the show view calls source.match(...) without a nil guard.
  let(:takedown) { create(:takedown, source: "http://example.com") }

  # ---------------------------------------------------------------------------
  # GET /takedowns — index
  # ---------------------------------------------------------------------------

  describe "GET /takedowns" do
    it "returns 200 for anonymous" do
      get takedowns_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for anonymous" do
      get takedowns_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with takedowns of different statuses" do
      let!(:pending_takedown)  { create(:takedown) }
      let!(:approved_takedown) { create(:takedown).tap { |t| t.update_columns(status: "approved") } }

      it "filters by status=pending" do
        get takedowns_path(search: { status: "pending" }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(pending_takedown.id)
        expect(ids).not_to include(approved_takedown.id)
      end

      it "filters by status=approved" do
        get takedowns_path(search: { status: "approved" }, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(approved_takedown.id)
        expect(ids).not_to include(pending_takedown.id)
      end
    end

    it "accepts moderator-level search params as bd_staff" do
      sign_in_as bd_staff
      get takedowns_path(search: { source: "http://example.com" }, format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /takedowns/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /takedowns/:id" do
    it "returns 200 for anonymous" do
      get takedown_path(takedown)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 when the vericode matches" do
      get takedown_path(takedown, code: takedown.vericode)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /takedowns/new — new
  # ---------------------------------------------------------------------------

  describe "GET /takedowns/new" do
    it "returns 200 for anonymous when takedowns are enabled" do
      get new_takedown_path
      expect(response).to have_http_status(:ok)
    end

    it "blocks access when takedowns are disabled" do
      allow(Security::Lockdown).to receive(:takedowns_disabled?).and_return(true)
      get new_takedown_path
      # Anonymous + HTML + GET → redirect to login
      expect(response).to redirect_to(new_session_path(url: new_takedown_path))
    end

    it "returns 403 for a signed-in member when takedowns are disabled" do
      sign_in_as member
      allow(Security::Lockdown).to receive(:takedowns_disabled?).and_return(true)
      get new_takedown_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /takedowns/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /takedowns/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_takedown_path(takedown)
      expect(response).to redirect_to(new_session_path(url: edit_takedown_path(takedown)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_takedown_path(takedown)
      expect(response).to have_http_status(:forbidden)
    end

    # FIXME: edit.html.erb does not exist — the action has no view template.
    # it "returns 200 for bd_staff" do
    #   sign_in_as bd_staff
    #   get edit_takedown_path(takedown)
    #   expect(response).to have_http_status(:ok)
    # end
  end

  # ---------------------------------------------------------------------------
  # POST /takedowns — create
  # ---------------------------------------------------------------------------

  describe "POST /takedowns" do
    let(:valid_params) do
      { takedown: { email: "dmca@example.com", reason: "This infringes my copyright.", instructions: "Remove all copies." } }
    end

    it "creates a takedown and redirects to show with the vericode" do
      expect { post takedowns_path, params: valid_params }.to change(Takedown, :count).by(1)
      expect(response).to redirect_to(takedown_path(id: Takedown.last.id, code: Takedown.last.vericode))
    end

    it "re-renders new when validation fails" do
      expect do
        post takedowns_path, params: { takedown: { email: "", reason: "", instructions: "" } }
      end.not_to change(Takedown, :count)
      expect(response).to have_http_status(:ok)
    end

    context "when takedowns are disabled" do
      before { allow(Security::Lockdown).to receive(:takedowns_disabled?).and_return(true) }

      it "redirects anonymous to login" do
        post takedowns_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for a signed-in member" do
        sign_in_as member
        post takedowns_path, params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /takedowns/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /takedowns/:id" do
    # takedown_posts intentionally omitted: passing "" raises because apply_posts calls #each on a String.
    let(:update_params) { { takedown: { notes: "Updated notes.", reason_hidden: false } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch takedown_path(takedown), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch takedown_path(takedown, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch takedown_path(takedown), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "updates the takedown and sets a success flash" do
        patch takedown_path(takedown), params: update_params
        expect(takedown.reload.notes).to eq("Updated notes.")
        expect(flash[:notice]).to eq("Takedown request updated")
      end

      it "enqueues a TakedownJob when process_takedown is truthy" do
        patch takedown_path(takedown), params: update_params.merge(process_takedown: "1", delete_reason: "DMCA")
        expect(TakedownJob).to have_been_enqueued
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /takedowns/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /takedowns/:id" do
    it "redirects anonymous to the login page" do
      delete takedown_path(takedown)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete takedown_path(takedown)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "destroys the takedown" do
        td_id = takedown.id
        expect { delete takedown_path(takedown) }.to change(Takedown, :count).by(-1)
        expect(Takedown.find_by(id: td_id)).to be_nil
      end

      it "logs a ModAction" do
        td_id = takedown.id
        delete takedown_path(takedown)
        expect(ModAction.last.action).to eq("takedown_delete")
        expect(ModAction.last[:values]).to include("takedown_id" => td_id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /takedowns/:id/add_by_ids — add_by_ids
  # ---------------------------------------------------------------------------

  describe "POST /takedowns/:id/add_by_ids" do
    let(:post_record) { create(:post) }

    it "returns 403 for a member" do
      sign_in_as member
      post add_by_ids_takedown_path(takedown, format: :json), params: { post_ids: post_record.id.to_s }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns JSON with added count for bd_staff" do
      sign_in_as bd_staff
      post add_by_ids_takedown_path(takedown, format: :json), params: { post_ids: post_record.id.to_s }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("added_count", "added_post_ids")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /takedowns/:id/add_by_tags — add_by_tags
  # ---------------------------------------------------------------------------

  describe "POST /takedowns/:id/add_by_tags" do
    it "returns 403 for a member" do
      sign_in_as member
      post add_by_tags_takedown_path(takedown, format: :json), params: { post_tags: "tagme" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns JSON with added count for bd_staff" do
      sign_in_as bd_staff
      post add_by_tags_takedown_path(takedown, format: :json), params: { post_tags: "tagme" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("added_count", "added_post_ids")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /takedowns/count_matching_posts — count_matching_posts
  # ---------------------------------------------------------------------------

  describe "POST /takedowns/count_matching_posts" do
    it "returns 403 for a member" do
      sign_in_as member
      post count_matching_posts_takedowns_path(format: :json), params: { post_tags: "tagme" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns matched_post_count JSON for bd_staff" do
      sign_in_as bd_staff
      post count_matching_posts_takedowns_path(format: :json), params: { post_tags: "tagme" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("matched_post_count")
    end
  end

  # ---------------------------------------------------------------------------
  # POST /takedowns/:id/remove_by_ids — remove_by_ids
  # ---------------------------------------------------------------------------

  describe "POST /takedowns/:id/remove_by_ids" do
    let(:td_with_post) { create(:takedown_with_post) }

    it "returns 403 for a member" do
      sign_in_as member
      post remove_by_ids_takedown_path(td_with_post, format: :json), params: { post_ids: "" }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 204 for bd_staff" do
      sign_in_as bd_staff
      post remove_by_ids_takedown_path(td_with_post, format: :json), params: { post_ids: "" }
      expect(response).to have_http_status(:no_content)
    end
  end
end
