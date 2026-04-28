# frozen_string_literal: true

require "rails_helper"

RSpec.describe ModActionsController do
  include_context "as admin"

  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }

  let(:mod_action) do
    create(:mod_action, action: "user_feedback_create",
                        values: { "user_id" => 1, "reason" => "test", "type" => "positive", "record_id" => 1 })
  end

  let(:protected_mod_action) do
    create(:mod_action, action: "staff_note_create",
                        values: { "id" => 1, "user_id" => 1, "body" => "note" })
  end

  # ---------------------------------------------------------------------------
  # GET /mod_actions — index
  # ---------------------------------------------------------------------------

  describe "GET /mod_actions" do
    it "returns 200 for anonymous" do
      get mod_actions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get mod_actions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "excludes protected actions from the JSON array for non-staff" do
      mod_action
      protected_mod_action
      get mod_actions_path(format: :json)
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(mod_action.id)
      expect(ids).not_to include(protected_mod_action.id)
    end

    it "includes protected actions in the JSON array for staff" do
      mod_action
      protected_mod_action
      sign_in_as moderator
      get mod_actions_path(format: :json)
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(mod_action.id, protected_mod_action.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /mod_actions/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /mod_actions/:id" do
    it "redirects to mod_actions_path with an id search filter for HTML" do
      get mod_action_path(mod_action)
      expect(response).to redirect_to(mod_actions_path(search: { id: mod_action.id }))
    end

    it "returns 200 for JSON (non-protected action, anonymous)" do
      get mod_action_path(mod_action, format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "when the action is protected and the user is anonymous" do
      it "redirects to the login page for HTML" do
        get mod_action_path(protected_mod_action)
        expect(response).to redirect_to(new_session_path(url: mod_action_path(protected_mod_action)))
      end

      it "returns 403 for JSON" do
        get mod_action_path(protected_mod_action, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the action is protected and the user is a non-staff member" do
      before { sign_in_as member }

      it "returns 403 for HTML" do
        get mod_action_path(protected_mod_action)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for JSON" do
        get mod_action_path(protected_mod_action, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the action is protected and the user is a staff member" do
      before { sign_in_as moderator }

      it "redirects to mod_actions_path with an id search filter for HTML" do
        get mod_action_path(protected_mod_action)
        expect(response).to redirect_to(mod_actions_path(search: { id: protected_mod_action.id }))
      end

      it "returns 200 for JSON" do
        get mod_action_path(protected_mod_action, format: :json)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
