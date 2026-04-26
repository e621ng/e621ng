# frozen_string_literal: true

require "rails_helper"

#    edit_histories GET  /edit_histories(.:format)     edit_histories#index
#     edit_history  GET  /edit_histories/:id(.:format) edit_histories#show
#
# Both actions require moderator level or above.

RSpec.describe EditHistoriesController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  let(:editor)    { create(:user) }
  let(:blip)      { create(:blip) }

  let!(:edit_record) do
    create(:edit_history, body: "searchable body", versionable: blip, user: editor)
  end

  # ---------------------------------------------------------------------------
  # GET /edit_histories — index
  # ---------------------------------------------------------------------------

  describe "GET /edit_histories" do
    it "redirects anonymous to the login page (HTML)" do
      get edit_histories_path
      expect(response).to redirect_to(new_session_path(url: edit_histories_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get edit_histories_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get edit_histories_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_histories_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a moderator" do
      sign_in_as moderator
      get edit_histories_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    describe "body_matches search param" do
      let!(:other_edit) { create(:edit_history, body: "unrelated content") }

      it "includes only matching records" do
        sign_in_as moderator
        get edit_histories_path(format: :json, search: { body_matches: "searchable" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(edit_record.id)
        expect(ids).not_to include(other_edit.id)
      end
    end

    describe "ip_addr search param" do
      # ip_addr is not in the moderator's permitted params list; the app is
      # configured with action_on_unpermitted_parameters = :raise so passing
      # it raises UnpermittedParameters which is rescued as access_denied (403).
      it "returns 403 for a non-admin moderator who passes ip_addr" do
        sign_in_as moderator
        get edit_histories_path(format: :json, search: { ip_addr: "127.0.0.1/32" })
        expect(response).to have_http_status(:forbidden)
      end

      it "filters results when used by an admin" do
        sign_in_as admin
        get edit_histories_path(format: :json, search: { ip_addr: "127.0.0.1/32" })
        expect(response).to have_http_status(:ok)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(edit_record.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /edit_histories/:id — show
  #
  # The show action treats :id as the versionable_id and reads versionable type
  # from params[:type]. It returns all EditHistory records for that versionable.
  # ---------------------------------------------------------------------------

  describe "GET /edit_histories/:id" do
    it "redirects anonymous to the login page (HTML)" do
      get edit_history_path(blip.id, type: "Blip")
      expect(response).to redirect_to(new_session_path(url: edit_history_path(blip.id, type: "Blip")))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get edit_history_path(blip.id, type: "Blip")
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get edit_history_path(blip.id, type: "Blip")
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a moderator" do
      sign_in_as moderator
      get edit_history_path(blip.id, format: :json, type: "Blip")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes the edit record for the given versionable" do
      sign_in_as moderator
      get edit_history_path(blip.id, format: :json, type: "Blip")
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(edit_record.id)
    end

    it "returns an empty array when the type does not match" do
      sign_in_as moderator
      get edit_history_path(blip.id, format: :json, type: "Comment")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_empty
    end
  end
end
