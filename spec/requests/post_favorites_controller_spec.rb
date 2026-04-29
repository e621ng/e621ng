# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFavoritesController do
  include_context "as admin"

  let(:member)    { create(:user) }
  let(:janitor)   { create(:janitor_user) }
  let(:moderator) { create(:moderator_user) }
  let(:post_rec)  { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /posts/:post_id/favorites — index
  # ---------------------------------------------------------------------------

  describe "GET /posts/:post_id/favorites" do
    it "returns 200 for anonymous" do
      get post_favorites_path(post_id: post_rec.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for HTML format" do
      sign_in_as member
      get post_favorites_path(post_id: post_rec.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 and a JSON array for JSON format" do
      get post_favorites_path(post_id: post_rec.id, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "returns 404 for a non-existent post" do
      get post_favorites_path(post_id: 0, format: :json)
      expect(response).to have_http_status(:not_found)
    end

    context "when listing favoriting users" do
      let(:favoriter) { create(:user) }
      let(:non_favoriter) { create(:user) }

      before { FavoriteManager.add!(user: favoriter, post: post_rec) }

      it "includes users who have favorited the post" do
        get post_favorites_path(post_id: post_rec.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(favoriter.id)
      end

      it "does not include users who have not favorited the post" do
        get post_favorites_path(post_id: post_rec.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).not_to include(non_favoriter.id)
      end

      it "returns users ordered by name alphabetically" do
        alpha = create(:user, name: "aaa_user")
        omega = create(:user, name: "zzz_user")
        FavoriteManager.add!(user: alpha, post: post_rec)
        FavoriteManager.add!(user: omega, post: post_rec)
        get post_favorites_path(post_id: post_rec.id, format: :json)
        names = response.parsed_body.pluck("name")
        expect(names).to eq(names.sort)
      end

      it "returns the expected JSON fields" do
        get post_favorites_path(post_id: post_rec.id, format: :json)
        entry = response.parsed_body.find { |u| u["id"] == favoriter.id }
        expect(entry).to include("id", "name", "level_string", "favorite_count")
      end
    end

    context "when the post has hide_favorites_list set" do
      before do
        post_rec.update_columns(
          bit_flags: post_rec.bit_flags | Post.flag_value_for("hide_favorites_list"),
        )
      end

      it "returns 403 for anonymous" do
        get post_favorites_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for a member" do
        sign_in_as member
        get post_favorites_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a janitor" do
        sign_in_as janitor
        get post_favorites_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a moderator" do
        sign_in_as moderator
        get post_favorites_path(post_id: post_rec.id, format: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when a favoriting user has privacy mode enabled" do
      let(:private_user) { create(:user) }

      before do
        FavoriteManager.add!(user: private_user, post: post_rec)
        private_user.update_columns(bit_prefs: private_user.bit_prefs | User.flag_value_for("enable_privacy_mode"))
      end

      it "excludes the private user for anonymous" do
        get post_favorites_path(post_id: post_rec.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).not_to include(private_user.id)
      end

      it "excludes the private user for a member" do
        sign_in_as member
        get post_favorites_path(post_id: post_rec.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).not_to include(private_user.id)
      end

      it "includes the private user for a moderator" do
        sign_in_as moderator
        get post_favorites_path(post_id: post_rec.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(private_user.id)
      end
    end

    context "with a limit param" do
      before do
        3.times { FavoriteManager.add!(user: create(:user), post: post_rec) }
      end

      it "respects the limit param" do
        get post_favorites_path(post_id: post_rec.id, format: :json), params: { limit: 1 }
        expect(response.parsed_body.size).to eq(1)
      end

      it "clamps limit to 100 when given a value above 100" do
        get post_favorites_path(post_id: post_rec.id, format: :json), params: { limit: 999 }
        expect(response).to have_http_status(:ok)
      end

      it "clamps limit to 1 when given a value below 1" do
        get post_favorites_path(post_id: post_rec.id, format: :json), params: { limit: 0 }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
