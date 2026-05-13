# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppealsController do
  include_context "as admin"

  let(:uploader)     { create(:user) }
  let(:other_member) { create(:user) }
  let(:janitor)      { create(:janitor_user) }
  let(:admin)        { create(:admin_user) }
  # uploader must be passed explicitly — the :post factory always creates its own uploader user.
  let(:flagged_post) { create(:post, uploader: uploader) }
  let(:post_flag)    { CurrentUser.scoped(other_member) { create(:post_flag, post: flagged_post) } }
  let(:appeal)       { CurrentUser.scoped(uploader) { create(:appeal, post_flag: post_flag) } }

  # ---------------------------------------------------------------------------
  # GET /appeals — index
  # ---------------------------------------------------------------------------

  describe "GET /appeals" do
    it "returns 200 for anonymous" do
      get appeals_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get appeals_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as uploader
      get appeals_path
      expect(response).to have_http_status(:ok)
    end

    it "accepts the reason search param as a janitor without error" do
      sign_in_as janitor
      get appeals_path(search: { reason: "anything" })
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a member who passes the staff-only reason search param" do
      sign_in_as uploader
      get appeals_path(search: { reason: "anything" })
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /appeals/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /appeals/:id" do
    it "redirects anonymous HTML to the login page" do
      get appeal_path(appeal)
      expect(response).to redirect_to(new_session_path(url: appeal_path(appeal)))
    end

    it "returns 403 for anonymous JSON" do
      get appeal_path(appeal, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for the appeal creator" do
      sign_in_as uploader
      get appeal_path(appeal)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a member who did not create the appeal" do
      sign_in_as other_member
      get appeal_path(appeal)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor" do
      sign_in_as janitor
      get appeal_path(appeal)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /appeals/new — new
  # ---------------------------------------------------------------------------

  describe "GET /appeals/new" do
    it "redirects anonymous to the login page" do
      get new_appeal_path
      expect(response).to redirect_to(new_session_path(url: new_appeal_path))
    end

    it "returns 403 for a member who is not the post uploader" do
      sign_in_as other_member
      get new_appeal_path(qtype: "flag", disp_id: post_flag.id)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for the post uploader" do
      sign_in_as uploader
      get new_appeal_path(qtype: "flag", disp_id: post_flag.id)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /appeals — create
  # ---------------------------------------------------------------------------

  describe "POST /appeals" do
    let(:valid_params) { { appeal: { qtype: "flag", disp_id: post_flag.id, reason: "The flag is wrong." } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post appeals_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post appeals_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member who is not the post uploader" do
      sign_in_as other_member
      post appeals_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as the post uploader" do
      before { sign_in_as uploader }

      it "creates an appeal and redirects to the appeal page" do
        expect { post appeals_path, params: valid_params }.to change(Appeal, :count).by(1)
        expect(response).to redirect_to(appeal_path(Appeal.last))
      end

      it "re-renders new when the reason is blank" do
        expect do
          post appeals_path, params: { appeal: { qtype: "flag", disp_id: post_flag.id, reason: "" } }
        end.not_to change(Appeal, :count)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /appeals/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /appeals/:id" do
    let(:update_params) { { appeal: { response: "Approved, the flag was incorrect.", status: "approved" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch appeal_path(appeal), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch appeal_path(appeal, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a regular member" do
      sign_in_as uploader
      patch appeal_path(appeal), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "updates the appeal status and response" do
        patch appeal_path(appeal), params: update_params
        expect(appeal.reload.status).to eq("approved")
        expect(appeal.reload.response).to eq("Approved, the flag was incorrect.")
      end

      context "when the appeal is already claimed by another janitor" do
        let(:other_janitor) { create(:janitor_user) }

        before { appeal.update_columns(claimant_id: other_janitor.id) }

        it "redirects back with a conflict flash notice" do
          patch appeal_path(appeal), params: update_params
          expect(response).to redirect_to(appeal_path(appeal, force_claim: "true"))
          expect(flash[:notice]).to eq("Appeal has already been claimed by somebody else, submit again to force")
        end

        it "updates when force_claim is set" do
          patch appeal_path(appeal), params: update_params.merge(force_claim: "true")
          expect(appeal.reload.status).to eq("approved")
        end
      end

      context "with send_update_dmail set but no changes to status or response" do
        before { appeal.update_columns(status: Appeal.statuses[:approved], response: "Already handled.") }

        it "sets a flash notice about not sending update" do
          patch appeal_path(appeal), params: { appeal: { status: "approved", response: "Already handled.", send_update_dmail: "1" } }
          expect(flash[:notice]).to eq("Not sending update, no changes")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /appeals/:id/claim — claim
  # ---------------------------------------------------------------------------

  describe "POST /appeals/:id/claim" do
    it "returns 403 for anonymous" do
      post claim_appeal_path(appeal, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a regular member" do
      sign_in_as uploader
      post claim_appeal_path(appeal, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "claims the appeal and sets claimant_id" do
        post claim_appeal_path(appeal, format: :json)
        expect(response).to have_http_status(:created)
        expect(appeal.reload.claimant_id).to eq(janitor.id)
      end

      context "when already claimed" do
        before { appeal.update_columns(claimant_id: janitor.id) }

        it "returns 201 with an already-claimed flash" do
          post claim_appeal_path(appeal, format: :json)
          expect(response).to have_http_status(:created)
          expect(flash[:notice]).to eq("Appeal already claimed")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /appeals/:id/unclaim — unclaim
  # ---------------------------------------------------------------------------

  describe "POST /appeals/:id/unclaim" do
    it "returns 403 for anonymous" do
      post unclaim_appeal_path(appeal, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a regular member" do
      sign_in_as uploader
      post unclaim_appeal_path(appeal, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "sets a flash notice when the appeal is not claimed" do
        post unclaim_appeal_path(appeal, format: :json)
        expect(response).to have_http_status(:created)
        expect(flash[:notice]).to eq("Appeal not claimed")
      end

      context "when claimed by another janitor" do
        let(:other_janitor) { create(:janitor_user) }

        before { appeal.update_columns(claimant_id: other_janitor.id) }

        it "sets a flash notice that the appeal is not claimed by the current user" do
          post unclaim_appeal_path(appeal, format: :json)
          expect(flash[:notice]).to eq("Appeal not claimed by you")
        end
      end

      context "when the appeal is approved and claimed by the janitor" do
        before { appeal.update_columns(claimant_id: janitor.id, status: Appeal.statuses[:approved]) }

        it "sets a flash notice that approved appeals cannot be unclaimed" do
          post unclaim_appeal_path(appeal, format: :json)
          expect(flash[:notice]).to eq("Cannot unclaim approved appeal")
        end
      end

      context "when the appeal is claimed by the janitor" do
        before { appeal.update_columns(claimant_id: janitor.id) }

        it "removes the claim and sets a success flash" do
          post unclaim_appeal_path(appeal, format: :json)
          expect(appeal.reload.claimant_id).to be_nil
          expect(flash[:notice]).to eq("Claim removed")
        end
      end
    end
  end
end
