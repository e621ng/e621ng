# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistVersionsController do
  before { skip "Artist versions routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artist_versions_path) }

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe "#index" do
    let!(:artist_alpha)    { CurrentUser.scoped(user,  "127.0.0.1") { create(:artist,          name: "av_spec_alpha") } }
    let!(:artist_beta)     { CurrentUser.scoped(user2, "10.0.0.1")  { create(:artist,          name: "av_spec_beta") } }
    let!(:artist_inactive) { CurrentUser.scoped(user,  "127.0.0.1") { create(:inactive_artist, name: "av_spec_inactive") } }

    let(:version_alpha)    { artist_alpha.versions.first }
    let(:version_beta)     { artist_beta.versions.first }
    let(:version_inactive) { artist_inactive.versions.first }

    it "renders successfully as JSON" do
      get artist_versions_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("id")).to include(version_alpha.id, version_beta.id, version_inactive.id)
    end

    it "renders successfully as HTML" do
      sign_in_as user
      get artist_versions_path
      expect(response).to have_http_status(:success)
    end

    context "with name param" do
      it "returns the matching version for an exact name" do
        get artist_versions_path(format: :json, params: { search: { name: "av_spec_alpha" } })
        expect(response.parsed_body.pluck("id")).to include(version_alpha.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_beta.id, version_inactive.id)
      end

      it "supports a trailing wildcard" do
        get artist_versions_path(format: :json, params: { search: { name: "av_spec_*" } })
        expect(response.parsed_body.pluck("id")).to include(version_alpha.id, version_beta.id, version_inactive.id)
      end
    end

    context "with updater_id param" do
      it "returns only versions created by the given user" do
        get artist_versions_path(format: :json, params: { search: { updater_id: user2.id } })
        expect(response.parsed_body.pluck("id")).to include(version_beta.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_alpha.id, version_inactive.id)
      end
    end

    context "with updater_name param" do
      it "returns only versions created by the named user" do
        get artist_versions_path(format: :json, params: { search: { updater_name: user2.name } })
        expect(response.parsed_body.pluck("id")).to include(version_beta.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_alpha.id, version_inactive.id)
      end
    end

    context "with artist_id param" do
      it "filters by a single artist_id" do
        get artist_versions_path(format: :json, params: { search: { artist_id: artist_alpha.id.to_s } })
        expect(response.parsed_body.pluck("id")).to include(version_alpha.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_beta.id, version_inactive.id)
      end

      it "accepts comma-separated artist_ids" do
        get artist_versions_path(format: :json, params: { search: { artist_id: "#{artist_alpha.id},#{artist_beta.id}" } })
        expect(response.parsed_body.pluck("id")).to include(version_alpha.id, version_beta.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_inactive.id)
      end
    end

    context "with is_active param" do
      it "returns only active versions when is_active is true" do
        get artist_versions_path(format: :json, params: { search: { is_active: "true" } })
        expect(response.parsed_body.pluck("id")).to include(version_alpha.id, version_beta.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_inactive.id)
      end

      it "returns only inactive versions when is_active is false" do
        get artist_versions_path(format: :json, params: { search: { is_active: "false" } })
        expect(response.parsed_body.pluck("id")).to include(version_inactive.id)
        expect(response.parsed_body.pluck("id")).not_to include(version_alpha.id, version_beta.id)
      end
    end

    context "with ip_addr param" do
      context "as admin" do
        let(:admin) { create(:admin_user) }

        it "filters by IP address" do
          sign_in_as(admin)
          get artist_versions_path(format: :json, params: { search: { ip_addr: "10.0.0.1" } })
          expect(response).to have_http_status(:success)
          expect(response.parsed_body.pluck("id")).to include(version_beta.id)
          expect(response.parsed_body.pluck("id")).not_to include(version_alpha.id, version_inactive.id)
        end
      end

      context "as a regular member" do
        it "returns 403 when ip_addr param is submitted" do
          sign_in_as(user)
          get artist_versions_path(format: :json, params: { search: { ip_addr: "10.0.0.1" } })
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "with order param" do
      it "orders by name when order is 'name'" do
        get artist_versions_path(format: :json, params: { search: { name: "av_spec_*", order: "name" } })
        names = response.parsed_body.pluck("name")
        expect(names).to eq(names.sort)
      end
    end
  end
end
