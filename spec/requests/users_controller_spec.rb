# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  # ---------------------------------------------------------------------------
  # GET /users — index
  # ---------------------------------------------------------------------------

  describe "GET /users" do
    it "returns 200 without a name param" do
      get users_path
      expect(response).to have_http_status(:ok)
    end

    context "with a name param matching an existing user" do
      let(:user) { create(:user) }

      it "redirects to the user profile" do
        get users_path(name: user.name)
        expect(response).to redirect_to(user_path(id: user.name))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /users/:id" do
    let(:user) { create(:user) }

    it "returns 200 for HTML" do
      get user_path(user)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with a JSON body containing the user id" do
      get user_path(user, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => user.id)
    end

    it "returns 404 for a non-existent user" do
      get user_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/search
  # ---------------------------------------------------------------------------

  describe "GET /users/search" do
    it "returns 200" do
      get search_users_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id/upload_limit — logged_in_only
  # ---------------------------------------------------------------------------

  describe "GET /users/:id/upload_limit" do
    let(:user) { create(:user) }

    context "as anonymous" do
      it "redirects to the login page" do
        get upload_limit_user_path(user)
        expect(response).to redirect_to(new_session_path(url: upload_limit_user_path(user)))
      end
    end

    context "as the user themselves" do
      before { sign_in_as user }

      it "returns 200" do
        get upload_limit_user_path(user)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/new
  # ---------------------------------------------------------------------------

  describe "GET /users/new" do
    it "returns 200 for anonymous" do
      get new_user_path
      expect(response).to have_http_status(:ok)
    end

    context "when already logged in" do
      before { sign_in_as create(:user) }

      it "redirects back with a notice for HTML requests" do
        get new_user_path
        expect(response).to redirect_to(posts_path)
        expect(flash[:notice]).to include("already signed in")
      end

      it "returns 403 for JSON requests" do
        get new_user_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when signups are disabled" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:enable_signups?).and_return(false)
      end

      # access_denied is called directly (not via PrivilegeError) for an anonymous user,
      # so the anonymous-GET path redirects to the login page rather than rendering 403.
      it "redirects to the login page" do
        get new_user_path
        expect(response).to redirect_to(new_session_path(url: new_user_path))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/me
  # ---------------------------------------------------------------------------

  describe "GET /users/me" do
    context "as anonymous" do
      it "returns 404" do
        get me_users_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as a logged-in member" do
      let(:user) { create(:user) }

      before { sign_in_as user }

      it "redirects to the user profile" do
        get me_users_path
        expect(response).to redirect_to(user_path(user))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/home
  # ---------------------------------------------------------------------------

  describe "GET /users/home" do
    it "returns 200 for anonymous" do
      get home_users_path
      expect(response).to have_http_status(:ok)
    end

    context "as a logged-in member" do
      before { sign_in_as create(:user) }

      it "returns 200" do
        get home_users_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id/edit — logged_in_only
  # ---------------------------------------------------------------------------

  describe "GET /users/:id/edit" do
    let(:user) { create(:user) }

    context "as anonymous" do
      it "redirects to the login page" do
        get edit_user_path(user)
        expect(response).to redirect_to(new_session_path(url: edit_user_path(user)))
      end
    end

    context "as the user themselves" do
      before { sign_in_as user }

      it "returns 200" do
        get edit_user_path(user)
        expect(response).to have_http_status(:ok)
      end
    end

    # The edit action always loads User.find(CurrentUser.id), ignoring the URL's :id.
    # Any authenticated user therefore sees their own edit form, not a 403.
    context "as a different member navigating to another user's edit path" do
      let(:other) { create(:user) }

      before { sign_in_as other }

      it "renders the current user's own edit form" do
        get edit_user_path(user)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(other.name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/custom_style — member_only
  # ---------------------------------------------------------------------------

  # The view template is custom_style.css.erb, so authenticated requests use format :css
  # (as stylesheet_link_tag produces in the application layout).
  # access_denied only handles HTML and JSON formats, so the anonymous test uses HTML.
  describe "GET /users/custom_style" do
    context "as anonymous" do
      it "redirects to the login page" do
        get custom_style_users_path
        expect(response).to redirect_to(new_session_path(url: custom_style_users_path))
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 200 with a CSS content type" do
        get custom_style_users_path(format: :css)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/css")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/avatar_menu — member_only (JSON only)
  # ---------------------------------------------------------------------------

  describe "GET /users/avatar_menu" do
    context "as anonymous" do
      it "returns 403 for JSON requests" do
        get avatar_menu_users_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 200 with the expected JSON keys" do
        get avatar_menu_users_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.keys).to contain_exactly(
          "has_uploads", "has_favorites", "has_sets", "has_comments", "has_forums"
        )
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /users — create
  # ---------------------------------------------------------------------------

  describe "POST /users" do
    let(:valid_params) do
      {
        user: {
          name: "signup_test_user",
          email: "signup_test_user@example.com",
          password: "hexerade",
          password_confirmation: "hexerade",
        },
      }
    end

    before do
      allow(Danbooru.config.custom_configuration).to receive_messages(
        enable_recaptcha?: false,
        enable_sock_puppet_validation?: false,
      )
    end

    context "as anonymous with valid params" do
      it "creates the user and redirects" do
        expect { post users_path, params: valid_params }
          .to change(User, :count).by(1)
        expect(response).to have_http_status(:found)
      end
    end

    context "as anonymous with a blank name" do
      let(:invalid_params) { valid_params.deep_merge(user: { name: "" }) }

      it "does not create a user" do
        expect { post users_path, params: invalid_params }
          .not_to change(User, :count)
      end
    end

    context "as a logged-in user" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        post users_path, params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when email verification is enabled" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:enable_email_verification?).and_return(true)
        ActionMailer::Base.deliveries.clear
      end

      it "sends a confirmation email" do
        expect { post users_path, params: valid_params }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /users/:id — update (logged_in_only)
  # ---------------------------------------------------------------------------

  describe "PATCH /users/:id" do
    let(:user) { create(:user) }

    context "as anonymous" do
      it "redirects to the login page" do
        patch user_path(user), params: { user: { time_zone: "UTC" } }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as the user themselves" do
      before { sign_in_as user }

      it "updates the user and redirects to settings" do
        patch user_path(user), params: { user: { time_zone: "UTC" } }
        expect(response).to redirect_to(settings_users_path)
        expect(user.reload.time_zone).to eq("UTC")
      end
    end

    # The update action always loads User.find(CurrentUser.id), ignoring the URL's :id.
    # Any authenticated user therefore updates their own profile, not another user's.
    context "as a different member navigating to another user's update path" do
      let(:other) { create(:user, time_zone: "UTC") }

      before { sign_in_as other }

      it "updates the current user's profile and leaves the target user unchanged" do
        patch user_path(user), params: { user: { time_zone: "Hawaii" } }
        expect(other.reload.time_zone).to eq("Hawaii")
        expect(user.reload.time_zone).not_to eq("Hawaii")
        expect(response).to redirect_to(settings_users_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id/toggle_uploads — janitor_only
  # ---------------------------------------------------------------------------

  describe "GET /users/:id/toggle_uploads" do
    let(:target) { create(:user) }

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        get toggle_uploads_user_path(target)
        expect(response).to have_http_status(:forbidden)
      end
    end

    # is_staff? (i.e. is_janitor?) is required inside the action to show the form.
    context "as a janitor when the target's uploads are enabled" do
      before { sign_in_as create(:janitor_user) }

      it "renders the disable-uploads form with status 200" do
        get toggle_uploads_user_path(target)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a janitor when the target's uploads are disabled" do
      let(:target) { create(:user, no_uploading: true) }

      before { sign_in_as create(:janitor_user) }

      it "re-enables uploads and redirects" do
        expect { get toggle_uploads_user_path(target) }
          .to change { target.reload.no_uploading }.from(true).to(false)
        expect(response).to redirect_to(user_path(target))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /users/:id/disable_uploads
  # (guarded by check_upload_disable_reason, which requires can_view_staff_notes?)
  # ---------------------------------------------------------------------------

  describe "POST /users/:id/disable_uploads" do
    let(:target) { create(:user) }

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        post disable_uploads_user_path(target), params: { staff_note: { body: "reason" } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor" do
      before { sign_in_as create(:janitor_user) }

      context "when the target's uploads are already disabled" do
        let(:target) { create(:user, no_uploading: true) }

        it "redirects with an 'already disabled' notice" do
          post disable_uploads_user_path(target), params: { staff_note: { body: "reason" } }
          expect(response).to redirect_to(user_path(target))
          expect(flash[:notice]).to include("already disabled")
        end
      end

      context "when no reason is provided" do
        it "redirects back with a 'must include a reason' notice" do
          post disable_uploads_user_path(target), params: { staff_note: { body: "" } }
          expect(response).to redirect_to(toggle_uploads_user_path(target))
          expect(flash[:notice]).to include("must include a reason")
        end
      end

      context "with a valid reason" do
        it "disables uploads, creates a StaffNote, and redirects" do
          expect { post disable_uploads_user_path(target), params: { staff_note: { body: "Spamming uploads." } } }
            .to change(StaffNote, :count).by(1)
          expect(target.reload.no_uploading).to be true
          expect(response).to redirect_to(user_path(target))
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id/fix_counts — janitor_only
  # ---------------------------------------------------------------------------

  describe "GET /users/:id/fix_counts" do
    let(:user) { create(:user) }

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        get fix_counts_user_path(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a janitor" do
      before { sign_in_as create(:janitor_user) }

      it "refreshes counts and redirects with a notice" do
        get fix_counts_user_path(user)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:notice]).to eq("Counts have been refreshed")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /users/:id/flush_favorites — admin_only
  # ---------------------------------------------------------------------------

  describe "POST /users/:id/flush_favorites" do
    let(:user) { create(:user) }

    context "as a janitor" do
      before { sign_in_as create(:janitor_user) }

      it "returns 403" do
        post flush_favorites_user_path(user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in_as create(:admin_user) }

      it "enqueues FlushFavoritesJob, logs a ModAction, and redirects" do
        expect { post flush_favorites_user_path(user) }
          .to have_enqueued_job(FlushFavoritesJob).with(user.id)
          .and change(ModAction, :count).by(1)
        expect(ModAction.last[:values]).to include("user_id" => user.id)
        expect(response).to redirect_to(user_path(user))
      end
    end
  end
end
