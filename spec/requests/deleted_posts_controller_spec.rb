# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeletedPostsController do
  before do
    CurrentUser.user    = create(:user)
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  describe "GET /deleted_posts" do
    context "without user_id" do
      it "allows anonymous access" do
        get deleted_posts_path
        expect(response).to have_http_status(:ok)
      end

      it "allows member access" do
        sign_in_as create(:user)
        get deleted_posts_path
        expect(response).to have_http_status(:ok)
      end

      it "shows posts sourced from deletion flags" do
        post_record = create(:post)
        create(:deletion_post_flag, post: post_record)
        post_record.update_columns(is_deleted: true)
        get deleted_posts_path
        expect(response.body).to include("/posts/#{post_record.id}")
      end

      it "excludes deleted posts that have no deletion flag" do
        post_record = create(:deleted_post)
        get deleted_posts_path
        expect(response.body).not_to include("/posts/#{post_record.id}")
      end

      it "returns 406 for JSON format" do
        get deleted_posts_path, params: { format: :json }
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context "with user_id" do
      it "returns 200 for an existing user" do
        user = create(:user)
        get deleted_posts_path(user_id: user.id)
        expect(response).to have_http_status(:ok)
      end

      it "shows deleted posts belonging to the target user" do
        target_user = create(:user)
        post_record = create(:post, uploader: target_user)
        create(:deletion_post_flag, post: post_record)
        post_record.update_columns(is_deleted: true)
        get deleted_posts_path(user_id: target_user.id)
        expect(response.body).to include("/posts/#{post_record.id}")
      end

      it "excludes deleted posts belonging to other users" do
        target_user = create(:user)
        other_user  = create(:user)
        other_post  = create(:post, uploader: other_user)
        create(:deletion_post_flag, post: other_post)
        other_post.update_columns(is_deleted: true)
        get deleted_posts_path(user_id: target_user.id)
        expect(response.body).not_to include("/posts/#{other_post.id}")
      end

      it "returns 404 when the user does not exist" do
        get deleted_posts_path(user_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
