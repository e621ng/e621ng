# frozen_string_literal: true

require "rails_helper"

RSpec.describe NoteVersionsController do
  include_context "as admin"

  let(:user)       { create(:user) }
  let(:admin_user) { create(:admin_user) }

  describe "GET /note_versions" do
    let!(:note)   { create(:note) }
    let(:version) { note.versions.first }

    it "returns 200 for anonymous" do
      get note_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as user
      get note_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get note_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes the auto-created version in the JSON response" do
      v = version
      get note_versions_path(format: :json)
      expect(response.parsed_body.pluck("id")).to include(v.id)
    end

    describe "search by updater_id" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:note).versions.first }
      end

      it "returns only versions for the given updater_id" do
        v = version
        get note_versions_path(format: :json, search: { updater_id: other_user.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by updater_name" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:note).versions.first }
      end

      it "returns only versions for the given updater_name" do
        v = version
        get note_versions_path(format: :json, search: { updater_name: other_user.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(v.id)
      end
    end

    describe "search by post_id" do
      let!(:other_note) { create(:note) }

      it "filters by a single post_id" do
        v = version
        other_v = other_note.versions.first
        get note_versions_path(format: :json, search: { post_id: note.post_id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end

      it "accepts comma-separated post_ids" do
        v = version
        other_v = other_note.versions.first
        get note_versions_path(format: :json, search: { post_id: "#{note.post_id},#{other_note.post_id}" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id, other_v.id)
      end
    end

    describe "search by note_id" do
      let!(:other_note) { create(:note) }

      it "filters by a single note_id" do
        v = version
        other_v = other_note.versions.first
        get note_versions_path(format: :json, search: { note_id: note.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end

      it "accepts comma-separated note_ids" do
        v = version
        other_v = other_note.versions.first
        get note_versions_path(format: :json, search: { note_id: "#{note.id},#{other_note.id}" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id, other_v.id)
      end
    end

    describe "search by is_active" do
      let!(:inactive_note) { create(:inactive_note) }

      it "returns active versions when is_active=true" do
        v = version
        inactive_v = inactive_note.versions.first
        get note_versions_path(format: :json, search: { is_active: "true" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(inactive_v.id)
      end

      it "returns inactive versions when is_active=false" do
        v = version
        inactive_v = inactive_note.versions.first
        get note_versions_path(format: :json, search: { is_active: "false" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(inactive_v.id)
        expect(ids).not_to include(v.id)
      end

      it "returns both active and inactive versions when is_active is not specified" do
        v = version
        inactive_v = inactive_note.versions.first
        get note_versions_path(format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id, inactive_v.id)
      end
    end

    describe "search by body_matches" do
      let!(:unique_note) { create(:note, body: "nvc_unique_body_text") }

      it "returns only versions matching the body" do
        v        = version
        unique_v = unique_note.versions.first
        get note_versions_path(format: :json, search: { body_matches: "nvc_unique_body_text" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(unique_v.id)
        expect(ids).not_to include(v.id)
      end

      it "supports a wildcard body match" do
        unique_v = unique_note.versions.first
        get note_versions_path(format: :json, search: { body_matches: "nvc_unique_*" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(unique_v.id)
      end
    end

    describe "search by ip_addr (admin-only)" do
      let!(:specific_ip_version) do
        CurrentUser.scoped(user, "9.9.9.9") { create(:note).versions.first }
      end

      it "filters by ip_addr when signed in as admin" do
        v  = version
        sv = specific_ip_version
        sign_in_as admin_user
        get note_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(sv.id)
        expect(ids).not_to include(v.id)
      end

      it "returns 403 when a non-admin passes ip_addr" do
        sign_in_as user
        get note_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "pagination" do
      before { 3.times { create(:note) } }

      it "respects the limit param" do
        get note_versions_path(format: :json, limit: 2)
        expect(response.parsed_body.size).to eq(2)
      end
    end
  end
end
