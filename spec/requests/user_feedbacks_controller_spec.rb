# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserFeedbacksController do
  include_context "as admin"

  let(:subject_user)    { create(:user) }
  let(:moderator)       { create(:moderator_user) }
  let(:other_moderator) { create(:moderator_user) }
  let(:admin)           { create(:admin_user) }
  let(:member)          { create(:user) }

  # feedback created by `moderator`, about `subject_user`
  let(:feedback) do
    orig = CurrentUser.user
    CurrentUser.user = moderator
    create(:user_feedback, user: subject_user, creator: moderator)
  ensure
    CurrentUser.user = orig
  end

  # ---------------------------------------------------------------------------
  # GET /user_feedbacks — index (public)
  # ---------------------------------------------------------------------------

  describe "GET /user_feedbacks" do
    it "returns 200 for anonymous HTML" do
      get user_feedbacks_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for anonymous" do
      get user_feedbacks_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with visibility filtering" do
      let!(:active_feedback)  { create(:user_feedback, user: subject_user, creator: moderator) }
      let!(:deleted_feedback) { create(:deleted_user_feedback, user: subject_user, creator: moderator) }

      it "includes active feedback for a member" do
        sign_in_as member
        get user_feedbacks_path(format: :json)
        expect(response.parsed_body.pluck("id")).to include(active_feedback.id)
      end

      it "excludes deleted feedback for a member" do
        sign_in_as member
        get user_feedbacks_path(format: :json)
        expect(response.parsed_body.pluck("id")).not_to include(deleted_feedback.id)
      end

      it "allows staff to view deleted feedback via the deleted=all param" do
        sign_in_as moderator
        get user_feedbacks_path(format: :json, search: { deleted: "all" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(active_feedback.id, deleted_feedback.id)
      end
    end

    it "filters results by category" do
      positive_feedback = create(:user_feedback, user: subject_user, creator: moderator, category: "positive")
      negative_feedback = create(:user_feedback, user: subject_user, creator: moderator, category: "negative")
      get user_feedbacks_path(format: :json, search: { category: "positive" })
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(positive_feedback.id)
      expect(ids).not_to include(negative_feedback.id)
    end

    it "filters results by user_id" do
      other_user              = create(:user)
      feedback_for_subject    = create(:user_feedback, user: subject_user, creator: moderator)
      feedback_for_other_user = create(:user_feedback, user: other_user, creator: moderator)
      get user_feedbacks_path(format: :json, search: { user_id: subject_user.id })
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(feedback_for_subject.id)
      expect(ids).not_to include(feedback_for_other_user.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /user_feedbacks/:id — show (public, guarded for deleted)
  # ---------------------------------------------------------------------------

  describe "GET /user_feedbacks/:id" do
    it "returns 200 for an active feedback as anonymous" do
      get user_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an active feedback as a member" do
      sign_in_as member
      get user_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
    end

    context "with a deleted feedback" do
      before { feedback.update_columns(is_deleted: true) }

      it "redirects anonymous to the login page for HTML" do
        get user_feedback_path(feedback)
        expect(response).to redirect_to(new_session_path(url: user_feedback_path(feedback)))
      end

      it "returns 403 for anonymous JSON" do
        get user_feedback_path(feedback, format: :json)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for a member" do
        sign_in_as member
        get user_feedback_path(feedback)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for staff" do
        sign_in_as moderator
        get user_feedback_path(feedback)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /user_feedbacks/new — new
  # ---------------------------------------------------------------------------

  describe "GET /user_feedbacks/new" do
    it "redirects anonymous to the login page" do
      get new_user_feedback_path
      expect(response).to redirect_to(new_session_path(url: new_user_feedback_path))
    end

    it "returns 403 for anonymous JSON" do
      get new_user_feedback_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_user_feedback_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get new_user_feedback_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /user_feedbacks — create
  # ---------------------------------------------------------------------------

  describe "POST /user_feedbacks" do
    let(:valid_params) { { user_feedback: { body: "A positive note.", category: "positive", user_id: subject_user.id } } }

    it "redirects anonymous to the login page for HTML" do
      post user_feedbacks_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      post user_feedbacks_path(format: :json), params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post user_feedbacks_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "creates a feedback record" do
        expect { post user_feedbacks_path, params: valid_params }.to change(UserFeedback, :count).by(1)
      end

      it "redirects after creation" do
        post user_feedbacks_path, params: valid_params
        expect(response).to have_http_status(:redirect)
      end

      it "creates a record when identifying the subject by user_name" do
        params = { user_feedback: { body: "A positive note.", category: "positive", user_name: subject_user.name } }
        expect { post user_feedbacks_path, params: params }.to change(UserFeedback, :count).by(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /user_feedbacks/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /user_feedbacks/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_user_feedback_path(feedback)
      expect(response).to redirect_to(new_session_path(url: edit_user_feedback_path(feedback)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_user_feedback_path(feedback)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator who is not the subject" do
      sign_in_as other_moderator
      get edit_user_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for the moderator who is the subject of the feedback" do
      feedback_about_moderator = create(:user_feedback, user: moderator, creator: other_moderator)
      sign_in_as moderator
      get edit_user_feedback_path(feedback_about_moderator)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin who is not the subject" do
      sign_in_as admin
      get edit_user_feedback_path(feedback)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /user_feedbacks/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /user_feedbacks/:id" do
    let(:update_params) { { user_feedback: { body: "Updated feedback body." } } }

    it "redirects anonymous to the login page for HTML" do
      patch user_feedback_path(feedback), params: update_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      patch user_feedback_path(feedback, format: :json), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch user_feedback_path(feedback), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for the moderator who is the subject of the feedback" do
      feedback_about_moderator = create(:user_feedback, user: moderator, creator: other_moderator)
      sign_in_as moderator
      patch user_feedback_path(feedback_about_moderator), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as the creating moderator" do
      before { sign_in_as moderator }

      it "updates the body" do
        patch user_feedback_path(feedback), params: update_params
        expect(feedback.reload.body).to eq("Updated feedback body.")
      end

      it "redirects after update" do
        patch user_feedback_path(feedback), params: update_params
        expect(response).to have_http_status(:redirect)
      end

      it "sets a flash notice when send_update_dmail is true but the body is unchanged" do
        unchanged_params = { user_feedback: { body: feedback.body, send_update_dmail: "true" } }
        patch user_feedback_path(feedback), params: unchanged_params
        expect(flash[:notice]).to eq("Not sending update, body not changed")
      end

      it "does not set the dmail flash when send_update_dmail is true and the body changes" do
        params = { user_feedback: { body: "New body text.", send_update_dmail: "true" } }
        patch user_feedback_path(feedback), params: params
        expect(flash[:notice]).not_to eq("Not sending update, body not changed")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /user_feedbacks/:id/delete — soft delete
  # ---------------------------------------------------------------------------

  describe "PUT /user_feedbacks/:id/delete" do
    it "redirects anonymous to the login page for HTML" do
      put delete_user_feedback_path(feedback)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      put delete_user_feedback_path(feedback, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      put delete_user_feedback_path(feedback)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for the moderator who is the subject" do
      feedback_about_moderator = create(:user_feedback, user: moderator, creator: other_moderator)
      sign_in_as moderator
      put delete_user_feedback_path(feedback_about_moderator)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator (not the subject)" do
      before { sign_in_as moderator }

      it "soft-deletes the feedback" do
        expect { put delete_user_feedback_path(feedback) }.to change { feedback.reload.is_deleted }.from(false).to(true)
      end

      it "sets the flash notice to 'Feedback deleted'" do
        put delete_user_feedback_path(feedback)
        expect(flash[:notice]).to eq("Feedback deleted")
      end

      it "redirects after deletion" do
        put delete_user_feedback_path(feedback)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /user_feedbacks/:id/undelete — undelete
  # ---------------------------------------------------------------------------

  describe "PUT /user_feedbacks/:id/undelete" do
    before { feedback.update_columns(is_deleted: true) }

    it "redirects anonymous to the login page for HTML" do
      put undelete_user_feedback_path(feedback)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      put undelete_user_feedback_path(feedback, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      put undelete_user_feedback_path(feedback)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for the moderator who is the subject" do
      feedback_about_moderator = create(:user_feedback, user: moderator, creator: other_moderator)
      feedback_about_moderator.update_columns(is_deleted: true)
      sign_in_as moderator
      put undelete_user_feedback_path(feedback_about_moderator)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator (not the subject)" do
      before { sign_in_as moderator }

      it "undeletes the feedback" do
        expect { put undelete_user_feedback_path(feedback) }.to change { feedback.reload.is_deleted }.from(true).to(false)
      end

      it "sets the flash notice to 'Feedback undeleted'" do
        put undelete_user_feedback_path(feedback)
        expect(flash[:notice]).to eq("Feedback undeleted")
      end

      it "redirects after undeleting" do
        put undelete_user_feedback_path(feedback)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /user_feedbacks/:id — hard destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /user_feedbacks/:id" do
    it "redirects anonymous to the login page for HTML" do
      delete user_feedback_path(feedback)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for anonymous JSON" do
      delete user_feedback_path(feedback, format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete user_feedback_path(feedback)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator who is not the creator" do
      sign_in_as other_moderator
      delete user_feedback_path(feedback)
      expect(response).to have_http_status(:forbidden)
    end

    context "when the feedback record already exists" do
      before { feedback }

      it "destroys the feedback for the moderator who created it" do
        sign_in_as moderator
        expect { delete user_feedback_path(feedback) }.to change(UserFeedback, :count).by(-1)
      end

      it "redirects after destruction for the creator moderator" do
        sign_in_as moderator
        delete user_feedback_path(feedback)
        expect(response).to have_http_status(:redirect)
      end

      it "destroys the feedback for an admin who is not the subject" do
        sign_in_as admin
        expect { delete user_feedback_path(feedback) }.to change(UserFeedback, :count).by(-1)
      end
    end
  end
end
