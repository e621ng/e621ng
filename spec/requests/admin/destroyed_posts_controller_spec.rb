# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DestroyedPostsController do
  include_context "as admin"

  let(:admin)    { create(:admin_user) }
  let(:bd_staff) { create(:bd_staff_user) }
  let(:user)     { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /admin/destroyed_posts
  # ---------------------------------------------------------------------------

  describe "GET /admin/destroyed_posts" do
    it "redirects anonymous to the login page" do
      get admin_destroyed_posts_path
      expect(response).to redirect_to(new_session_path(url: admin_destroyed_posts_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_destroyed_posts_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get admin_destroyed_posts_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/destroyed_posts/:id
  # ---------------------------------------------------------------------------

  describe "GET /admin/destroyed_posts/:id" do
    let(:destroyed_post) { create(:destroyed_post) }

    it "redirects anonymous to the login page" do
      get admin_destroyed_post_path(destroyed_post.post_id)
      expect(response).to redirect_to(new_session_path(url: admin_destroyed_post_path(destroyed_post.post_id)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get admin_destroyed_post_path(destroyed_post.post_id)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects to the index filtered by post_id for an admin" do
      sign_in_as admin
      get admin_destroyed_post_path(destroyed_post.post_id)
      expect(response).to redirect_to(admin_destroyed_posts_path(search: { post_id: destroyed_post.post_id.to_s }))
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /admin/destroyed_posts/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /admin/destroyed_posts/:id" do
    let(:destroyed_post) { create(:destroyed_post, notify: false) }

    it "redirects anonymous to the login page" do
      patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "true" } }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-BD-staff admin" do
      sign_in_as admin
      patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "true" } }
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "enables notifications and sets the correct flash message" do
        destroyed_post.update_columns(notify: false)
        patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "true" } }
        expect(destroyed_post.reload.notify).to be true
        expect(flash[:notice]).to eq("Re-uploads of that post will now notify admins")
      end

      it "disables notifications and sets the correct flash message" do
        destroyed_post.update_columns(notify: true)
        patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "false" } }
        expect(destroyed_post.reload.notify).to be false
        expect(flash[:notice]).to eq("Re-uploads of that post will no longer notify admins")
      end

      it "redirects to the index after update" do
        patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "true" } }
        expect(response).to redirect_to(admin_destroyed_posts_path)
      end

      it "logs enable_post_notifications to StaffAuditLog when notify is enabled" do
        destroyed_post.update_columns(notify: false)
        patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "true" } }
        expect(StaffAuditLog.last.action).to eq("enable_post_notifications")
        expect(StaffAuditLog.last[:values]).to include("post_id" => destroyed_post.post_id)
      end

      it "logs disable_post_notifications to StaffAuditLog when notify is disabled" do
        destroyed_post.update_columns(notify: true)
        patch admin_destroyed_post_path(destroyed_post.post_id), params: { destroyed_post: { notify: "false" } }
        expect(StaffAuditLog.last.action).to eq("disable_post_notifications")
        expect(StaffAuditLog.last[:values]).to include("post_id" => destroyed_post.post_id)
      end
    end
  end
end
