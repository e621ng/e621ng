# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AutomodDmailsController do
  include_context "as admin"

  let(:janitor) { create(:janitor_user) }
  let(:member)  { create(:user) }

  let(:system_dmail) { create(:dmail, from: User.system, to: create(:user), owner_id: User.system.id) }

  # ---------------------------------------------------------------------------
  # GET /admin/automod_dmails
  # ---------------------------------------------------------------------------

  describe "GET /admin/automod_dmails" do
    it "redirects anonymous to the login page" do
      get admin_automod_dmails_path
      expect(response).to redirect_to(new_session_path(url: admin_automod_dmails_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get admin_automod_dmails_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as janitor" do
      before { sign_in_as janitor }

      it "returns 200" do
        get admin_automod_dmails_path
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON response" do
        get admin_automod_dmails_path(format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "only lists dmails owned by the system user" do
        system_dmail
        other_dmail = create(:dmail)
        get admin_automod_dmails_path(format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(system_dmail.id)
        expect(ids).not_to include(other_dmail.id)
      end

      it "filters by title when a search param is provided" do
        matching   = create(:dmail, title: "AutomodAlert123", from: User.system, to: create(:user), owner_id: User.system.id)
        unmatching = create(:dmail, title: "UnrelatedTitle",  from: User.system, to: create(:user), owner_id: User.system.id)
        get admin_automod_dmails_path(format: :json, search: { title_matches: "AutomodAlert123" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(matching.id)
        expect(ids).not_to include(unmatching.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/automod_dmails/:id
  # ---------------------------------------------------------------------------

  describe "GET /admin/automod_dmails/:id" do
    it "redirects anonymous to the login page" do
      get admin_automod_dmail_path(system_dmail)
      expect(response).to redirect_to(new_session_path(url: admin_automod_dmail_path(system_dmail)))
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      get admin_automod_dmail_path(system_dmail)
      expect(response).to have_http_status(:forbidden)
    end

    context "as janitor" do
      before { sign_in_as janitor }

      it "returns 200" do
        get admin_automod_dmail_path(system_dmail)
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON response" do
        get admin_automod_dmail_path(system_dmail, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for a dmail not owned by the system user" do
        other_dmail = create(:dmail)
        get admin_automod_dmail_path(other_dmail)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
