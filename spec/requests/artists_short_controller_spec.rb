# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistsShortController do
  include_context "as member"

  describe "GET /a/*name" do
    let!(:artist) { create(:artist, name: "some_artist") }

    it "renders the artist page without redirecting" do
      get short_artist_path(artist.name)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Artist - some_artist")
    end

    it "renders for staff" do
      sign_in_as create(:janitor_user)
      get short_artist_path(artist.name)
      expect(response).to have_http_status(:ok)
    end

    it "redirects non-normalized names to the normalized path" do
      get short_artist_path("Some Artist")
      expect(response).to redirect_to(short_artist_path("some_artist"))
    end

    it "supports names containing a slash" do
      create(:artist, name: "foo/bar")
      get short_artist_path("foo/bar")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Artist - foo/bar")
    end

    it "treats a trailing .json as part of the name" do
      get "/a/some_artist.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown artist" do
      get short_artist_path("nobody_here")
      expect(response).to have_http_status(:not_found)
    end

    context "with an active alias" do
      before { create(:active_tag_alias, antecedent_name: "old_name", consequent_name: artist.name) }

      it "redirects the antecedent to the consequent" do
        get short_artist_path("old_name")
        expect(response).to redirect_to(short_artist_path(artist.name))
      end

      it "redirects even when an antecedent artist still exists" do
        create(:artist, name: "old_name")
        get short_artist_path("old_name")
        expect(response).to redirect_to(short_artist_path(artist.name))
      end

      it "redirects non-normalized antecedents straight to the consequent" do
        get short_artist_path("Old Name")
        expect(response).to redirect_to(short_artist_path(artist.name))
      end
    end

    %i[tag_alias deleted_tag_alias].each do |factory|
      context "with a #{factory.to_s.humanize(capitalize: false)}" do
        before { create(factory, antecedent_name: "old_name", consequent_name: artist.name) }

        it "ignores the alias" do
          get short_artist_path("old_name")
          expect(response).to have_http_status(:not_found)
        end

        it "renders the antecedent artist if it exists" do
          create(:artist, name: "old_name")
          get short_artist_path("old_name")
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
