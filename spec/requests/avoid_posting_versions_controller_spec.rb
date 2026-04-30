# frozen_string_literal: true

require "rails_helper"

#  avoid_posting_versions GET /avoid_posting_versions(.:format) avoid_posting_versions#index
RSpec.describe AvoidPostingVersionsController do
  before { skip "Avoid posting versions routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:avoid_posting_versions_path) }

  include_context "as admin"

  let(:user)       { create(:user) }
  let(:admin_user) { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # GET /avoid_posting_versions — index
  # ---------------------------------------------------------------------------

  describe "GET /avoid_posting_versions" do
    let!(:avoid_posting) { create(:avoid_posting) }
    let(:version)        { avoid_posting.versions.first }

    it "returns 200 for anonymous" do
      get avoid_posting_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as user
      get avoid_posting_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get avoid_posting_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes the auto-created version in the JSON response" do
      v = version
      get avoid_posting_versions_path(format: :json)
      expect(response.parsed_body.pluck("id")).to include(v.id)
    end

    describe "search by updater_id" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:avoid_posting).versions.first }
      end

      it "returns only versions for the given updater_id" do
        v = version
        get avoid_posting_versions_path(format: :json, search: { updater_id: CurrentUser.user.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_version.id)
      end
    end

    describe "search by updater_name" do
      let(:other_user) { create(:user) }
      let!(:other_version) do
        CurrentUser.scoped(other_user, "2.2.2.2") { create(:avoid_posting).versions.first }
      end

      it "returns only versions for the given updater_name" do
        v = version
        get avoid_posting_versions_path(format: :json, search: { updater_name: CurrentUser.user.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_version.id)
      end
    end

    describe "search by artist_name" do
      let!(:other_ap) { create(:avoid_posting) }

      it "returns only versions for the matching artist, excluding others" do
        v = version
        other_v = other_ap.versions.first
        get avoid_posting_versions_path(format: :json, search: { artist_name: avoid_posting.artist.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end
    end

    describe "search by artist_id" do
      let!(:other_ap) { create(:avoid_posting) }

      it "returns only versions for the matching artist_id, excluding others" do
        v = version
        other_v = other_ap.versions.first
        get avoid_posting_versions_path(format: :json, search: { artist_id: avoid_posting.artist_id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(v.id)
        expect(ids).not_to include(other_v.id)
      end
    end

    describe "search by is_active" do
      let!(:inactive_ap) { create(:inactive_avoid_posting) }
      let(:active_version)   { avoid_posting.versions.first }
      let(:inactive_version) { inactive_ap.versions.first }

      it "returns active versions when is_active=true" do
        av = active_version
        iv = inactive_version
        get avoid_posting_versions_path(format: :json, search: { is_active: "true" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(av.id)
        expect(ids).not_to include(iv.id)
      end

      it "returns inactive versions when is_active=false" do
        av = active_version
        iv = inactive_version
        get avoid_posting_versions_path(format: :json, search: { is_active: "false" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(iv.id)
        expect(ids).not_to include(av.id)
      end

      it "returns both active and inactive versions when is_active is not specified" do
        av = active_version
        iv = inactive_version
        get avoid_posting_versions_path(format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(av.id, iv.id)
      end
    end

    describe "search by ip_addr (admin-only)" do
      let!(:specific_ip_version) do
        CurrentUser.scoped(user, "9.9.9.9") { create(:avoid_posting).versions.first }
      end

      it "filters by ip_addr when signed in as admin" do
        v = version
        sv = specific_ip_version
        sign_in_as admin_user
        get avoid_posting_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(sv.id)
        expect(ids).not_to include(v.id)
      end

      it "returns 403 when a non-admin passes ip_addr" do
        sign_in_as user
        get avoid_posting_versions_path(format: :json, search: { ip_addr: "9.9.9.9" })
        expect(response).to have_http_status(:forbidden)
      end
    end

    # FIXME: group_name is permitted by the controller but is not forwarded to artist_search
    # inside AvoidPostingVersion.search (only artist_id, artist_name, any_name_matches, and
    # any_other_name_matches trigger the artist join), so this param has no filtering effect.
    # it "filters by group_name" do
    #   ...
    # end

    describe "pagination" do
      before do
        3.times { create(:avoid_posting) }
      end

      it "respects the limit param" do
        get avoid_posting_versions_path(format: :json, limit: 2)
        expect(response.parsed_body.size).to eq(2)
      end
    end
  end
end
