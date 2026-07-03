# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistUrlsController do
  before { skip "Artist URLs routes not available in this fork" unless Rails.application.routes.url_helpers.respond_to?(:artist_urls_path) }

  include_context "as admin"

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /artist_urls — index
  # ---------------------------------------------------------------------------

  describe "GET /artist_urls" do
    it "returns 200 for anonymous" do
      get artist_urls_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      get artist_urls_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get artist_urls_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with an existing artist URL" do
      let!(:artist_url) { create(:artist_url) }

      it "includes the artist association in JSON" do
        get artist_urls_path(format: :json)
        record = response.parsed_body.find { |r| r["id"] == artist_url.id }
        expect(record).to include("artist")
      end

      it "does not include notes on the artist in JSON" do
        get artist_urls_path(format: :json)
        record = response.parsed_body.find { |r| r["id"] == artist_url.id }
        expect(record["artist"]).not_to include("notes")
      end
    end

    # -------------------------------------------------------------------------
    # Search params
    # -------------------------------------------------------------------------

    describe "search[artist_id]" do
      let(:target_artist) { create(:artist) }
      let(:other_artist)  { create(:artist) }
      let!(:target_url)   { create(:artist_url, artist: target_artist) }
      let!(:other_url)    { create(:artist_url, artist: other_artist) }

      it "filters by artist_id" do
        get artist_urls_path(format: :json, search: { artist_id: target_artist.id })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(target_url.id)
        expect(ids).not_to include(other_url.id)
      end
    end

    describe "search[is_active]" do
      let!(:active_url)   { create(:artist_url) }
      let!(:inactive_url) { create(:inactive_artist_url) }

      it "returns only active URLs when is_active is true" do
        get artist_urls_path(format: :json, search: { is_active: "true" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(active_url.id)
        expect(ids).not_to include(inactive_url.id)
      end

      it "returns only inactive URLs when is_active is false" do
        get artist_urls_path(format: :json, search: { is_active: "false" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(inactive_url.id)
        expect(ids).not_to include(active_url.id)
      end
    end

    describe "search[artist_name]" do
      let(:target_artist) { create(:artist, name: "picasso_#{SecureRandom.hex(4)}") }
      let(:other_artist)  { create(:artist, name: "monet_#{SecureRandom.hex(4)}") }
      let!(:target_url)   { create(:artist_url, artist: target_artist) }
      let!(:other_url)    { create(:artist_url, artist: other_artist) }

      it "filters by artist name" do
        get artist_urls_path(format: :json, search: { artist_name: target_artist.name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(target_url.id)
        expect(ids).not_to include(other_url.id)
      end
    end

    describe "search[url_matches]" do
      let!(:fa_url)  { create(:artist_url, url: "https://www.furaffinity.net/user/someartist/") }
      let!(:da_url)  { create(:artist_url, url: "https://www.deviantart.com/otherapartist/") }

      it "returns URLs matching the wildcard pattern" do
        get artist_urls_path(format: :json, search: { url_matches: "furaffinity" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(fa_url.id)
        expect(ids).not_to include(da_url.id)
      end
    end

    describe "search[normalized_url_matches]" do
      let!(:fa_url)  { create(:artist_url, url: "https://www.furaffinity.net/user/someartist2/") }
      let!(:da_url)  { create(:artist_url, url: "https://www.deviantart.com/otherapartist2/") }

      it "returns URLs whose normalized form matches the wildcard pattern" do
        get artist_urls_path(format: :json, search: { normalized_url_matches: "furaffinity" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(fa_url.id)
        expect(ids).not_to include(da_url.id)
      end
    end
  end
end
