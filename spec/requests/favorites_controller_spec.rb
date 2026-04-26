# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoritesController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member) { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:post_record) { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /favorites — index
  # ---------------------------------------------------------------------------

  describe "GET /favorites" do
    it "returns 200 for anonymous" do
      get favorites_path(user_id: member.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for JSON format" do
      get favorites_path(user_id: member.id, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["posts"]).to be_an(Array)
    end

    it "redirects to posts path when tags param is a string" do
      get favorites_path(tags: "cat dog")
      expect(response).to redirect_to(posts_path(tags: "cat dog"))
    end

    it "returns 400 when tags param is not a string" do
      get favorites_path(format: :json), params: { tags: %w[cat dog] }
      expect(response).to have_http_status(:bad_request)
    end

    it "shows another user's favorites when user_id is given" do
      FavoriteManager.add!(user: other_member, post: post_record)
      sign_in_as member
      get favorites_path(user_id: other_member.id, format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "when the target user has privacy mode enabled" do
      before { other_member.update_columns(bit_prefs: other_member.bit_prefs | User.flag_value_for("enable_privacy_mode")) }

      it "returns 200 but an empty post list for another member" do
        sign_in_as member
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).to be_empty
      end

      it "returns favorites to the owner themselves" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as other_member
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end

      it "returns favorites to a moderator" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as moderator
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end
    end

    context "when the target user is blocked" do
      let(:blocked_user) { create(:banned_user) }

      it "returns 200 but an empty post list" do
        FavoriteManager.add!(user: blocked_user, post: post_record)
        get favorites_path(user_id: blocked_user.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).to be_empty
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /favorites — create
  # ---------------------------------------------------------------------------

  describe "POST /favorites" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post favorites_path, params: { post_id: post_record.id }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a favorite and returns post_id and favorite_count" do
        expect do
          post favorites_path(format: :json), params: { post_id: post_record.id }
        end.to change(Favorite, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_id" => post_record.id, "favorite_count" => 1)
      end

      it "returns 422 when the post is already favorited" do
        FavoriteManager.add!(user: member, post: post_record)
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 423 when favorites transfer is in progress" do
        post_record.update_columns(bit_flags: post_record.bit_flags | Post.flag_value_for("favorites_transfer_in_progress"))
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:locked)
      end

      it "returns 403 when favorites are locked down" do
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a staff member when favorites are locked down" do
      before do
        sign_in_as moderator
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
      end

      it "still allows creating a favorite" do
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /favorites/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /favorites/:id" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        delete favorite_path(post_record.id)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before do
        sign_in_as member
        FavoriteManager.add!(user: member, post: post_record)
      end

      it "removes the favorite and returns post_id and favorite_count" do
        expect do
          delete favorite_path(post_record.id, format: :json)
        end.to change(Favorite, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_id" => post_record.id, "favorite_count" => 0)
      end

      it "returns 423 when favorites transfer is in progress" do
        post_record.update_columns(bit_flags: post_record.bit_flags | Post.flag_value_for("favorites_transfer_in_progress"))
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:locked)
      end

      it "returns 403 when favorites are locked down" do
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a staff member when favorites are locked down" do
      before do
        sign_in_as moderator
        FavoriteManager.add!(user: moderator, post: post_record)
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
      end

      it "still allows removing a favorite" do
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
