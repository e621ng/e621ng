# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistsShortController do
  include_context "as member"

  describe "GET /a/:name" do
    let!(:artist) { create(:artist, name: "some_artist") }

    it "renders the artist page without redirecting" do
      get short_artist_path(artist.name)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Artist - some_artist")
    end

    it "declares the short URL as canonical" do
      get short_artist_path(artist.name)
      expect(response.body).to match(%r{<link rel="canonical" href="https://[^/"]+/a/some_artist">})
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

    it "still resolves a raw interior slash" do
      create(:artist, name: "foo/bar")
      get "/a/foo/bar"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Artist - foo/bar")
    end

    context "with a name starting and ending in a slash" do
      # Legacy data: the tag name validator now rejects a leading slash, so rename behind its back.
      let!(:slashed_artist) do
        create(:artist, name: "delicious_legacy").tap do |artist|
          artist.tag.update_columns(name: "/delicious/")
          artist.update_columns(name: "/delicious/")
        end
      end

      before { create(:tag, name: "delicious") }

      it "percent-encodes the slashes in the generated path" do
        expect(short_artist_path(slashed_artist.name)).to eq("/a/%2Fdelicious%2F")
      end

      it "renders the slashed artist rather than the inner tag" do
        get short_artist_path(slashed_artist.name)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Artist - /delicious/")
        expect(response.body).not_to include("Artist - delicious<")
      end

      it "declares the encoded short URL as canonical" do
        get short_artist_path(slashed_artist.name)
        expect(response.body).to match(%r{<link rel="canonical" href="https://[^/"]+/a/%2Fdelicious%2F">})
      end
    end

    it "treats a trailing .json as part of the name" do
      get "/a/some_artist.json"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when neither an artist nor a tag exists" do
      get short_artist_path("nobody_here")
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a non-artist tag" do
      create(:tag, name: "general_tag")
      get short_artist_path("general_tag")
      expect(response).to have_http_status(:not_found)
    end

    context "with an artist tag but no artist entry" do
      before { create(:artist_tag, name: "unlisted_artist") }

      it "renders the page with a link to create the entry" do
        get short_artist_path("unlisted_artist")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Artist - unlisted_artist")
        expect(response.body).to include("Create new artist entry")
        expect(response.body).to include('<meta name="robots" content="noindex" />')
      end

      it "shows the subscribe button" do
        sign_in_as create(:user)
        get short_artist_path("unlisted_artist")
        expect(response.body).to include("tag-subscription-toggle")
      end

      it "does not create an artist entry" do
        expect { get short_artist_path("unlisted_artist") }.not_to change(Artist, :count)
      end
    end

    it "does not offer to create an existing artist" do
      get short_artist_path(artist.name)
      expect(response.body).not_to include("Create new artist entry")
      expect(response.body).not_to include('content="noindex"')
    end

    context "with an active alias" do
      before { create(:active_tag_alias, antecedent_name: "old_name", consequent_name: artist.name) }

      it "redirects the antecedent to the consequent" do
        get short_artist_path("old_name")
        expect(response).to redirect_to(short_artist_path(artist.name, from: "old_name"))
      end

      it "redirects even when an antecedent artist still exists" do
        create(:artist, name: "old_name")
        get short_artist_path("old_name")
        expect(response).to redirect_to(short_artist_path(artist.name, from: "old_name"))
      end

      it "redirects non-normalized antecedents straight to the consequent" do
        get short_artist_path("Old Name")
        expect(response).to redirect_to(short_artist_path(artist.name, from: "old_name"))
      end

      it "notes where the visitor was redirected from" do
        get short_artist_path(artist.name, from: "old_name")
        expect(response.body).to include("Redirected from")
      end

      it "ignores a from param that is not aliased here" do
        get short_artist_path(artist.name, from: "unrelated")
        expect(response.body).not_to include("Redirected from")
      end

      it "does not list leftover entries when there are none" do
        get short_artist_path(artist.name)
        expect(response.body).not_to include("Artist entries still exist")
      end

      context "with a leftover antecedent artist" do
        before { create(:artist, name: "old_name") }

        it "renders the leftover with redirect=no" do
          get short_artist_path("old_name", redirect: "no")
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Artist - old_name")
          expect(response.body).to include("This artist entry was left behind")
          expect(response.body).to include('content="noindex"')
        end

        it "keeps redirect=no when normalizing the name" do
          get short_artist_path("Old Name", redirect: "no")
          expect(response).to redirect_to(short_artist_path("old_name", redirect: "no"))
        end

        it "lists the leftover on the consequent's page" do
          get short_artist_path(artist.name)
          expect(response.body).to include("Artist entries still exist")
          expect(response.body).to include(short_artist_path("old_name", redirect: "no"))
        end
      end

      it "still redirects with redirect=no when no antecedent artist exists" do
        get short_artist_path("old_name", redirect: "no")
        expect(response).to redirect_to(short_artist_path(artist.name, from: "old_name"))
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
