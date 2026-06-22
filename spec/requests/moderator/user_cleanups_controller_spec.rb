# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::UserCleanupsController do
  let(:target)    { create(:user, profile_about: "hello", profile_artinfo: "world") }
  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # GET /moderator/user_cleanups/:user_id
  # ---------------------------------------------------------------------------

  describe "GET /moderator/user_cleanups/:user_id" do
    it "redirects anonymous to the login page" do
      get moderator_user_cleanup_path(target)
      expect(response).to redirect_to(new_session_path(url: moderator_user_cleanup_path(target)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/user_cleanups/:user_id/clear_avatar
  # ---------------------------------------------------------------------------

  describe "POST /moderator/user_cleanups/:user_id/clear_avatar" do
    it "redirects anonymous to the login page" do
      post clear_avatar_moderator_user_cleanup_path(target)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-moderator" do
      sign_in_as member
      post clear_avatar_moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      it "clears the user's avatar and redirects with a notice" do
        sign_in_as moderator

        avatar = CurrentUser.scoped(moderator) { create(:post) }
        target.update!(avatar_id: avatar.id)

        post clear_avatar_moderator_user_cleanup_path(target)
        expect(response).to redirect_to(moderator_user_cleanup_path(target))
        expect(flash[:notice]).to eq("User avatar cleared")
        expect(target.reload.avatar_id).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/user_cleanups/:user_id/clear_profile
  # ---------------------------------------------------------------------------

  describe "POST /moderator/user_cleanups/:user_id/clear_profile" do
    before { sign_in_as moderator }

    it "returns 403 for a member" do
      sign_in_as member
      post clear_profile_moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it "clears profile_about and profile_artinfo" do
      post clear_profile_moderator_user_cleanup_path(target)
      expect(target.reload.profile_about).to eq("")
      expect(target.reload.profile_artinfo).to eq("")
    end

    it "creates a staff note with the archived content" do
      expect do
        post clear_profile_moderator_user_cleanup_path(target)
      end.to change(StaffNote, :count).by(1)

      note = StaffNote.last
      expect(note.user_id).to eq(target.id)
      expect(note.body).to include("hello")
      expect(note.body).to include("world")
    end

    it "logs a user_profile_clear ModAction" do
      expect do
        post clear_profile_moderator_user_cleanup_path(target)
      end.to change { ModAction.where(action: "user_profile_clear").count }.by(1)
    end

    it "redirects back to the cleanup page" do
      post clear_profile_moderator_user_cleanup_path(target)
      expect(response).to redirect_to(moderator_user_cleanup_path(target))
    end

    context "when both profile fields are already blank" do
      let(:target) { create(:user, profile_about: "", profile_artinfo: "") }

      it "still creates a staff note" do
        expect do
          post clear_profile_moderator_user_cleanup_path(target)
        end.to change(StaffNote, :count).by(1)
      end

      it "does not include archived content section in the note" do
        post clear_profile_moderator_user_cleanup_path(target)
        expect(StaffNote.last.body).not_to include("[section=About]")
        expect(StaffNote.last.body).not_to include("[section=Art Info]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/user_cleanups/:user_id/hide_comments
  # ---------------------------------------------------------------------------

  describe "POST /moderator/user_cleanups/:user_id/hide_comments" do
    before { sign_in_as moderator }

    it "returns 403 for a member" do
      sign_in_as member
      post hide_comments_moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues HideUserCommentsJob" do
      expect do
        post hide_comments_moderator_user_cleanup_path(target)
      end.to have_enqueued_job(HideUserCommentsJob).with(target.id, moderator.id)
    end

    it "logs a user_comments_hide ModAction" do
      expect do
        post hide_comments_moderator_user_cleanup_path(target)
      end.to change { ModAction.where(action: "user_comments_hide").count }.by(1)
    end

    it "redirects back to the cleanup page" do
      post hide_comments_moderator_user_cleanup_path(target)
      expect(response).to redirect_to(moderator_user_cleanup_path(target))
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/user_cleanups/:user_id/hide_forum_posts
  # ---------------------------------------------------------------------------

  describe "POST /moderator/user_cleanups/:user_id/hide_forum_posts" do
    before { sign_in_as moderator }

    it "returns 403 for a member" do
      sign_in_as member
      post hide_forum_posts_moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues HideUserForumPostsJob" do
      expect do
        post hide_forum_posts_moderator_user_cleanup_path(target)
      end.to have_enqueued_job(HideUserForumPostsJob).with(target.id, moderator.id)
    end

    it "logs a user_forum_posts_hide ModAction" do
      expect do
        post hide_forum_posts_moderator_user_cleanup_path(target)
      end.to change { ModAction.where(action: "user_forum_posts_hide").count }.by(1)
    end

    it "redirects back to the cleanup page" do
      post hide_forum_posts_moderator_user_cleanup_path(target)
      expect(response).to redirect_to(moderator_user_cleanup_path(target))
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/user_cleanups/:user_id/hide_blips
  # ---------------------------------------------------------------------------

  describe "POST /moderator/user_cleanups/:user_id/hide_blips" do
    before { sign_in_as moderator }

    it "returns 403 for a member" do
      sign_in_as member
      post hide_blips_moderator_user_cleanup_path(target)
      expect(response).to have_http_status(:forbidden)
    end

    it "enqueues HideUserBlipsJob" do
      expect do
        post hide_blips_moderator_user_cleanup_path(target)
      end.to have_enqueued_job(HideUserBlipsJob).with(target.id, moderator.id)
    end

    it "logs a user_blips_delete ModAction" do
      expect do
        post hide_blips_moderator_user_cleanup_path(target)
      end.to change { ModAction.where(action: "user_blips_delete").count }.by(1)
    end

    it "redirects back to the cleanup page" do
      post hide_blips_moderator_user_cleanup_path(target)
      expect(response).to redirect_to(moderator_user_cleanup_path(target))
    end
  end
end
