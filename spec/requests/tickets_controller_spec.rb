# frozen_string_literal: true

require "rails_helper"

RSpec.describe TicketsController do
  include_context "as admin"

  let(:member)          { create(:user) }
  let(:other_member)    { create(:user) }
  let(:janitor)         { create(:janitor_user) }
  let(:moderator)       { create(:moderator_user) }
  let(:other_moderator) { create(:moderator_user) }
  let(:accused_user)    { create(:user) }

  # User-type ticket created as `member`. User-type visibility: moderator+ or creator only.
  let(:ticket) do
    CurrentUser.scoped(member) { create(:ticket, accused_user: accused_user) }
  end

  # Pool-type ticket created as `member`. Pool-type visibility: staff (janitor+) or creator.
  let(:pool_ticket) do
    CurrentUser.scoped(member) { create(:ticket, :pool_type) }
  end

  # ---------------------------------------------------------------------------
  # GET /tickets — index
  # ---------------------------------------------------------------------------

  describe "GET /tickets" do
    it "returns 200 for anonymous" do
      get tickets_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get tickets_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get tickets_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tickets/new — new
  # ---------------------------------------------------------------------------

  describe "GET /tickets/new" do
    it "redirects anonymous to the login page" do
      get new_ticket_path
      expect(response).to redirect_to(new_session_path(url: new_ticket_path))
    end

    it "returns 403 when qtype is absent" do
      sign_in_as member
      get new_ticket_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a member with a valid user qtype" do
      sign_in_as member
      get new_ticket_path(qtype: "user", disp_id: accused_user.id)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tickets — create (HTML only)
  # ---------------------------------------------------------------------------

  describe "POST /tickets" do
    let(:valid_params) { { ticket: { qtype: "user", disp_id: accused_user.id, reason: "This user is violating the rules." } } }

    context "as anonymous" do
      it "redirects to the login page" do
        post tickets_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a ticket and redirects to the show page" do
        expect { post tickets_path, params: valid_params }.to change(Ticket, :count).by(1)
        expect(response).to redirect_to(ticket_path(Ticket.last))
      end

      it "re-renders new when reason is blank" do
        expect { post tickets_path, params: { ticket: { qtype: "user", disp_id: accused_user.id, reason: "" } } }.not_to change(Ticket, :count)
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 when qtype is blank" do
        post tickets_path, params: { ticket: { qtype: "", disp_id: accused_user.id, reason: "Some reason here." } }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tickets/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /tickets/:id" do
    it "redirects anonymous to the login page" do
      get ticket_path(ticket)
      expect(response).to redirect_to(new_session_path(url: ticket_path(ticket)))
    end

    it "returns 200 for the creator" do
      sign_in_as member
      get ticket_path(ticket)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a non-creator member on a user-type ticket" do
      sign_in_as other_member
      get ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor on a user-type ticket" do
      sign_in_as janitor
      get ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a janitor on a pool-type ticket" do
      sign_in_as janitor
      get ticket_path(pool_ticket)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get ticket_path(ticket)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 as JSON for a moderator" do
      sign_in_as moderator
      get ticket_path(ticket, format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /tickets/:id — update (janitor_only gate; moderator effective)
  # ---------------------------------------------------------------------------

  describe "PATCH /tickets/:id" do
    let(:update_params) { { ticket: { response: "A valid response.", status: "approved" } } }

    it "redirects anonymous to the login page for HTML" do
      patch ticket_path(ticket), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch ticket_path(ticket), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      patch ticket_path(ticket), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "updates the ticket response and status" do
        patch ticket_path(ticket), params: update_params
        expect(ticket.reload.response).to eq("A valid response.")
        expect(ticket.reload.status).to eq("approved")
      end

      it "sets the handler to the current moderator" do
        patch ticket_path(ticket), params: update_params
        expect(ticket.reload.handler_id).to eq(moderator.id)
      end

      context "when the ticket is already claimed by another moderator" do
        before { ticket.update_columns(claimant_id: other_moderator.id) }

        it "redirects back with a flash notice when force_claim is absent" do
          patch ticket_path(ticket), params: update_params
          expect(response).to redirect_to(ticket_path(ticket, force_claim: "true"))
          expect(flash[:notice]).to match(/already been claimed/)
        end

        it "proceeds with the update when force_claim is present" do
          patch ticket_path(ticket), params: update_params.merge(force_claim: "true")
          expect(ticket.reload.status).to eq("approved")
        end
      end

      context "when send_update_dmail is true but nothing changed" do
        before { ticket.update_columns(response: "Unchanged response.", status: "approved") }

        it "sets a flash notice about no changes" do
          patch ticket_path(ticket), params: { ticket: { response: "Unchanged response.", status: "approved", send_update_dmail: "true" } }
          expect(flash[:notice]).to eq("Not sending update, no changes")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tickets/:id/claim — claim (janitor_only gate; moderator effective)
  # ---------------------------------------------------------------------------

  describe "POST /tickets/:id/claim" do
    it "redirects anonymous to the login page" do
      post claim_ticket_path(ticket)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post claim_ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      post claim_ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "claims an unclaimed ticket" do
        post claim_ticket_path(ticket)
        expect(ticket.reload.claimant_id).to eq(moderator.id)
      end

      context "when the ticket is already claimed by another moderator" do
        before { ticket.update_columns(claimant_id: other_moderator.id) }

        it "does not change the claimant and sets a flash notice" do
          post claim_ticket_path(ticket)
          expect(ticket.reload.claimant_id).to eq(other_moderator.id)
          expect(flash[:notice]).to eq("Ticket already claimed")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tickets/:id/unclaim — unclaim (janitor_only gate; moderator effective)
  # ---------------------------------------------------------------------------

  describe "POST /tickets/:id/unclaim" do
    it "redirects anonymous to the login page" do
      post unclaim_ticket_path(ticket)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post unclaim_ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor" do
      sign_in_as janitor
      post unclaim_ticket_path(ticket)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "sets a flash notice when the ticket is not claimed" do
        post unclaim_ticket_path(ticket)
        expect(flash[:notice]).to eq("Ticket not claimed")
      end

      context "when the ticket is claimed by another moderator" do
        before { ticket.update_columns(claimant_id: other_moderator.id) }

        it "sets a flash notice when not claimed by the current user" do
          post unclaim_ticket_path(ticket)
          expect(flash[:notice]).to eq("Ticket not claimed by you")
        end
      end

      context "when the ticket is approved and claimed" do
        before { ticket.update_columns(claimant_id: moderator.id, status: "approved") }

        it "sets a flash notice about the approved status" do
          post unclaim_ticket_path(ticket)
          expect(flash[:notice]).to eq("Cannot unclaim approved ticket")
        end
      end

      context "when the ticket is claimed by the current moderator" do
        before { ticket.update_columns(claimant_id: moderator.id) }

        it "unclaims the ticket and sets a success flash notice" do
          post unclaim_ticket_path(ticket)
          expect(ticket.reload.claimant_id).to be_nil
          expect(flash[:notice]).to eq("Claim removed")
        end
      end
    end
  end
end
