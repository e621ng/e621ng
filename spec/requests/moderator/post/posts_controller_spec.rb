# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::Post::PostsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:approver)         { create(:approver_user) }
  let(:janitor)          { create(:janitor_user) }
  let(:janitor_approver) { create(:janitor_user, can_approve_posts: true) }
  let(:admin)            { create(:admin_user, can_approve_posts: true) }
  let(:member)           { create(:user) }
  let(:post_record)      { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /moderator/post/posts/:id/confirm_delete
  # ---------------------------------------------------------------------------

  describe "GET /moderator/post/posts/:id/confirm_delete" do
    it "redirects anonymous to the login page" do
      get confirm_delete_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: confirm_delete_moderator_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get confirm_delete_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an approver" do
      sign_in_as approver
      get confirm_delete_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/delete
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/delete" do
    it "redirects anonymous to the login page" do
      post delete_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post delete_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an approver" do
      before { sign_in_as approver }

      it "soft-deletes the post and redirects when commit=Delete with a reason" do
        post delete_moderator_post_post_path(post_record), params: { commit: "Delete", reason: "rule violation" }
        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.is_deleted?).to be true
      end

      it "redirects back to confirm_delete with a flash when reason is blank" do
        post delete_moderator_post_post_path(post_record), params: { commit: "Delete", reason: "" }
        expect(response).to redirect_to(confirm_delete_moderator_post_post_path(post_record))
        expect(flash[:notice]).to be_present
      end

      it "does not delete and redirects when commit is not Delete" do
        post delete_moderator_post_post_path(post_record), params: { commit: "Cancel" }
        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.is_deleted?).to be false
      end

      context "when the post is already deleted" do
        let(:post_record) { create(:deleted_post) }

        it "shows a flash notice and redirects for HTML" do
          post delete_moderator_post_post_path(post_record), params: { commit: "Delete", reason: "rule violation" }
          expect(response).to redirect_to(post_path(post_record))
          expect(flash[:notice]).to match(/already deleted/)
        end

        it "returns 409 for JSON" do
          post delete_moderator_post_post_path(post_record, format: :json), params: { commit: "Delete", reason: "rule violation" }
          expect(response).to have_http_status(:conflict)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/undelete
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/undelete" do
    let(:deleted_post) { create(:deleted_post) }

    it "redirects anonymous to the login page" do
      post undelete_moderator_post_post_path(deleted_post)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post undelete_moderator_post_post_path(deleted_post)
      expect(response).to have_http_status(:forbidden)
    end

    it "undeletes the post and redirects for an approver" do
      sign_in_as approver
      post undelete_moderator_post_post_path(deleted_post)
      expect(response).to redirect_to(post_path(deleted_post))
      expect(deleted_post.reload.is_deleted?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # GET /moderator/post/posts/:id/confirm_move_favorites
  # ---------------------------------------------------------------------------

  describe "GET /moderator/post/posts/:id/confirm_move_favorites" do
    it "redirects anonymous to the login page" do
      get confirm_move_favorites_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: confirm_move_favorites_moderator_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get confirm_move_favorites_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an approver" do
      sign_in_as approver
      get confirm_move_favorites_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/move_favorites
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/move_favorites" do
    it "redirects anonymous to the login page" do
      post move_favorites_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post move_favorites_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an approver" do
      before { sign_in_as approver }

      it "redirects to the post when commit is not Submit" do
        post move_favorites_moderator_post_post_path(post_record)
        expect(response).to redirect_to(post_path(post_record))
      end

      it "moves favorites and redirects when commit=Submit" do
        parent       = create(:post)
        post_record  = create(:post, parent: parent)
        post move_favorites_moderator_post_post_path(post_record), params: { commit: "Submit" }
        expect(response).to redirect_to(post_path(post_record))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/expunge
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/expunge" do
    it "redirects anonymous to the login page" do
      post expunge_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post expunge_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without admin level" do
      sign_in_as approver
      post expunge_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "expunges the post and redirects for an admin" do
      target = post_record
      allow_any_instance_of(Post).to receive(:expunge!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as admin
      post expunge_moderator_post_post_path(target)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/regenerate_thumbnails
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/regenerate_thumbnails" do
    it "redirects anonymous to the login page" do
      post regenerate_thumbnails_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post regenerate_thumbnails_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      post regenerate_thumbnails_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "regenerates thumbnails and redirects for a janitor" do
      allow_any_instance_of(Post).to receive(:regenerate_image_samples!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor
      post regenerate_thumbnails_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /moderator/post/posts/:id/regenerate_videos
  # ---------------------------------------------------------------------------

  describe "POST /moderator/post/posts/:id/regenerate_videos" do
    it "redirects anonymous to the login page" do
      post regenerate_videos_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post regenerate_videos_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      post regenerate_videos_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "regenerates video samples and redirects for a janitor" do
      allow_any_instance_of(Post).to receive(:regenerate_video_samples!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor
      post regenerate_videos_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end

    it "returns 403 for a deleted post" do
      deleted = create(:deleted_post)
      sign_in_as janitor
      post regenerate_videos_moderator_post_post_path(deleted)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /moderator/post/posts/:id/ai_check
  # ---------------------------------------------------------------------------

  describe "GET /moderator/post/posts/:id/ai_check" do
    it "redirects anonymous to the login page" do
      get ai_check_moderator_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: ai_check_moderator_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get ai_check_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      get ai_check_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without approver rights" do
      sign_in_as janitor
      get ai_check_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "runs the AI check and redirects for a janitor with approver rights" do
      allow_any_instance_of(Post).to receive(:check_for_ai_content).and_return({ score: 0, reason: "" }) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor_approver
      get ai_check_moderator_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end
  end
end
