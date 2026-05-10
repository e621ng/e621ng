# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UsersController do
  include_context "as admin"

  let(:admin)    { create(:admin_user) }
  let(:bd_staff) { create(:bd_staff_user) }
  let(:user)     { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /admin/users/alt_list
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/alt_list" do
    it "redirects anonymous to the login page" do
      get alt_list_admin_users_path
      expect(response).to redirect_to(new_session_path(url: alt_list_admin_users_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get alt_list_admin_users_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get alt_list_admin_users_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON response for an admin" do
      sign_in_as admin
      get alt_list_admin_users_path(format: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/users/:id/edit
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_admin_user_path(user)
      expect(response).to redirect_to(new_session_path(url: edit_admin_user_path(user)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get edit_admin_user_path(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_admin_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /admin/users/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /admin/users/:id" do
    it "redirects anonymous to the login page" do
      patch admin_user_path(user), params: { user: { profile_about: "hello" } }
      expect(response).to redirect_to(new_session_path)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "updates profile_about" do
        patch admin_user_path(user), params: { user: { profile_about: "new about" } }
        expect(user.reload.profile_about).to eq("new about")
      end

      it "updates profile_artinfo" do
        patch admin_user_path(user), params: { user: { profile_artinfo: "art info" } }
        expect(user.reload.profile_artinfo).to eq("art info")
      end

      it "updates base_upload_limit" do
        patch admin_user_path(user), params: { user: { base_upload_limit: 42 } }
        expect(user.reload.base_upload_limit).to eq(42)
      end

      it "updates enable_privacy_mode" do
        patch admin_user_path(user), params: { user: { enable_privacy_mode: true } }
        expect(user.reload.enable_privacy_mode).to be true
      end

      it "logs a user_text_change ModAction when profile_about changes" do
        patch admin_user_path(user), params: { user: { profile_about: "changed" } }
        expect(ModAction.last.action).to eq("user_text_change")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "logs a user_text_change ModAction when profile_artinfo changes" do
        patch admin_user_path(user), params: { user: { profile_artinfo: "changed" } }
        expect(ModAction.last.action).to eq("user_text_change")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "logs a user_custom_title_change ModAction with a new value" do
        user.update_columns(custom_title: "")
        patch admin_user_path(user), params: { user: { custom_title: "Title" } }
        mod = ModAction.last
        expect(mod.action).to eq("user_custom_title_change")
        expect(mod[:values]).to include("user_id" => user.id, "old_custom_title" => "", "new_custom_title" => "Title")
      end

      it "logs a user_custom_title_change ModAction with a different value" do
        user.update_columns(custom_title: "Previous")
        patch admin_user_path(user), params: { user: { custom_title: "Changed" } }
        mod = ModAction.last
        expect(mod.action).to eq("user_custom_title_change")
        expect(mod[:values]).to include("user_id" => user.id, "old_custom_title" => "Previous", "new_custom_title" => "Changed")
      end

      it "logs a user_custom_title_change ModAction with no value" do
        user.update_columns(custom_title: "Previous")
        patch admin_user_path(user), params: { user: { custom_title: "" } }
        mod = ModAction.last
        expect(mod.action).to eq("user_custom_title_change")
        expect(mod[:values]).to include("user_id" => user.id, "old_custom_title" => "Previous", "new_custom_title" => "")
      end

      it "does not log user_custom_title_change when unchanged" do
        user.update_columns(custom_title: "Existing")
        expect do
          patch admin_user_path(user), params: { user: { custom_title: "Existing" } }
        end.not_to(change { ModAction.where(action: "user_custom_title_change").count })
      end

      it "logs a user_upload_limit_change ModAction with old and new values" do
        user.update_columns(base_upload_limit: 10)
        patch admin_user_path(user), params: { user: { base_upload_limit: 20 } }
        mod = ModAction.last
        expect(mod.action).to eq("user_upload_limit_change")
        expect(mod[:values]).to include("user_id" => user.id, "old_upload_limit" => 10, "new_upload_limit" => 20)
      end

      it "does not log user_upload_limit_change when limit is unchanged" do
        user.update_columns(base_upload_limit: 10)
        expect do
          patch admin_user_path(user), params: { user: { base_upload_limit: 10 } }
        end.not_to(change { ModAction.where(action: "user_upload_limit_change").count })
      end

      it "creates a UserNameChangeRequest when a new name is given" do
        expect do
          patch admin_user_path(user), params: { user: { profile_about: "x", name: "brand_new_name_abc" } }
        end.to change(UserNameChangeRequest, :count).by(1)
        expect(UserNameChangeRequest.last.desired_name).to eq("brand_new_name_abc")
      end

      it "logs a user_name_change ModAction when name changes" do
        patch admin_user_path(user), params: { user: { profile_about: "x", name: "another_new_name_abc" } }
        expect(ModAction.where(action: "user_name_change").exists?).to be true
      end

      it "does not create a UserNameChangeRequest when the name is unchanged" do
        expect do
          patch admin_user_path(user), params: { user: { profile_about: "x", name: user.name } }
        end.not_to change(UserNameChangeRequest, :count)
      end

      it "does not create a UserNameChangeRequest when name param is absent" do
        expect do
          patch admin_user_path(user), params: { user: { profile_about: "x" } }
        end.not_to change(UserNameChangeRequest, :count)
      end

      it "does not allow a non-BD-staff admin to change email" do
        original_email = user.email
        patch admin_user_path(user), params: { user: { email: "hacker@example.com" } }
        expect(user.reload.email).to eq(original_email)
      end

      it "does not change verification status when user is not BD staff" do
        user.update_columns(email_verification_key: "somekey")
        patch admin_user_path(user), params: { user: { profile_about: "x", verified: "1" } }
        expect(user.reload.email_verification_key).to eq("somekey")
      end

      it "redirects to the user page with a notice on success" do
        patch admin_user_path(user), params: { user: { profile_about: "ok" } }
        expect(response).to redirect_to(user_path(user))
        expect(flash[:notice]).to eq("User updated")
      end
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "allows updating email" do
        patch admin_user_path(user), params: { user: { email: "valid@example.com" } }
        expect(user.reload.email).to eq("valid@example.com")
      end

      it "marks the user as verified when verified param is truthy" do
        user.update_columns(email_verification_key: "pending")
        patch admin_user_path(user), params: { user: { profile_about: "x", verified: "1" } }
        expect(user.reload.email_verification_key).to be_nil
      end

      it "marks the user as unverified when verified param is falsy" do
        user.update_columns(email_verification_key: nil)
        patch admin_user_path(user), params: { user: { profile_about: "x", verified: "0" } }
        expect(user.reload.email_verification_key).not_to be_nil
      end

      it "promotes a user to a new level" do
        patch admin_user_path(user), params: { user: { profile_about: "x", level: User::Levels::PRIVILEGED } }
        expect(user.reload.level).to eq(User::Levels::PRIVILEGED)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/users/:id/edit_blacklist
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:id/edit_blacklist" do
    it "redirects anonymous to the login page" do
      get edit_blacklist_admin_user_path(user)
      expect(response).to redirect_to(new_session_path(url: edit_blacklist_admin_user_path(user)))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get edit_blacklist_admin_user_path(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_blacklist_admin_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/users/:id/update_blacklist
  # ---------------------------------------------------------------------------

  describe "POST /admin/users/:id/update_blacklist" do
    it "redirects anonymous to the login page" do
      post update_blacklist_admin_user_path(user), params: { user: { blacklisted_tags: "tag1" } }
      expect(response).to redirect_to(new_session_path)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "updates blacklisted_tags" do
        post update_blacklist_admin_user_path(user), params: { user: { blacklisted_tags: "tag1 tag2" } }
        expect(user.reload.blacklisted_tags).to eq("tag1 tag2")
      end

      it "logs a user_blacklist_changed ModAction" do
        post update_blacklist_admin_user_path(user), params: { user: { blacklisted_tags: "tag1" } }
        expect(ModAction.last.action).to eq("user_blacklist_changed")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "redirects to edit_blacklist with a notice" do
        post update_blacklist_admin_user_path(user), params: { user: { blacklisted_tags: "tag1" } }
        expect(response).to redirect_to(edit_blacklist_admin_user_path(user))
        expect(flash[:notice]).to eq("Blacklist updated")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/users/:id/request_password_reset
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:id/request_password_reset" do
    it "redirects anonymous to the login page" do
      get request_password_reset_admin_user_path(user)
      expect(response).to redirect_to(new_session_path(url: request_password_reset_admin_user_path(user)))
    end

    it "returns 403 for a non-BD-staff admin" do
      sign_in_as admin
      get request_password_reset_admin_user_path(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for BD staff" do
      sign_in_as bd_staff
      get request_password_reset_admin_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/users/:id/password_reset
  # ---------------------------------------------------------------------------

  describe "POST /admin/users/:id/password_reset" do
    it "redirects anonymous to the login page" do
      post password_reset_admin_user_path(user), params: { admin: { password: "hexerade" } }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-BD-staff admin" do
      sign_in_as admin
      post password_reset_admin_user_path(user), params: { admin: { password: "hexerade" } }
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "redirects back with a notice when the password is wrong" do
        post password_reset_admin_user_path(user), params: { admin: { password: "wrongpassword" } }
        expect(response).to redirect_to(request_password_reset_admin_user_path(user))
        expect(flash[:notice]).to eq("Password wrong")
      end

      it "creates a UserPasswordResetNonce when the password is correct" do
        expect do
          post password_reset_admin_user_path(user), params: { admin: { password: "hexerade" } }
        end.to change(UserPasswordResetNonce, :count).by(1)
      end

      it "renders the password_reset template when the password is correct" do
        post password_reset_admin_user_path(user), params: { admin: { password: "hexerade" } }
        expect(response).to have_http_status(:ok)
      end

      it "invalidates the old password when invalidate_old_password is truthy" do
        post password_reset_admin_user_path(user), params: {
          admin: { password: "hexerade", invalidate_old_password: "1" },
        }
        expect(user.reload.bcrypt_password_hash).to eq("*AC*")
      end

      it "preserves the old password hash when invalidate_old_password is not set" do
        original_hash = user.bcrypt_password_hash
        post password_reset_admin_user_path(user), params: { admin: { password: "hexerade" } }
        expect(user.reload.bcrypt_password_hash).to eq(original_hash)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /admin/users/:id/anonymize
  # ---------------------------------------------------------------------------

  describe "GET /admin/users/:id/anonymize" do
    it "redirects anonymous to the login page" do
      get anonymize_admin_user_path(user)
      expect(response).to redirect_to(new_session_path(url: anonymize_admin_user_path(user)))
    end

    it "returns 403 for a non-BD-staff admin" do
      sign_in_as admin
      get anonymize_admin_user_path(user)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "returns 200 for a normal user" do
        get anonymize_admin_user_path(user)
        expect(response).to have_http_status(:ok)
      end

      it "redirects with an alert when the target is a staff member" do
        staff = create(:janitor_user)
        get anonymize_admin_user_path(staff)
        expect(response).to redirect_to(user_path(staff))
        expect(flash[:alert]).to eq("Staff accounts cannot be deleted")
      end

      it "redirects with an alert when the account is already anonymized" do
        user.update_columns(name: "user_#{user.id}")
        get anonymize_admin_user_path(user)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:alert]).to eq("User account has already been deleted")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /admin/users/:id/anonymize (anonymize_confirm)
  # ---------------------------------------------------------------------------

  describe "POST /admin/users/:id/anonymize" do
    it "redirects anonymous to the login page" do
      post anonymize_admin_user_path(user)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-BD-staff admin" do
      sign_in_as admin
      post anonymize_admin_user_path(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects to the confirm_password page when reauthentication is missing" do
      sign_in_as bd_staff
      post anonymize_admin_user_path(user)
      expect(response).to redirect_to(confirm_password_session_path(url: anonymize_admin_user_path(user)))
    end

    context "as bd_staff with reauthentication" do
      before do
        sign_in_as bd_staff
        allow_any_instance_of(Admin::UsersController).to receive(:requires_reauthentication) # rubocop:disable RSpec/AnyInstance
      end

      it "redirects with an alert when the target is a staff member" do
        staff = create(:janitor_user)
        post anonymize_admin_user_path(staff)
        expect(response).to redirect_to(user_path(staff))
        expect(flash[:alert]).to eq("Staff accounts cannot be deleted")
      end

      it "redirects with an alert when the account is already anonymized" do
        user.update_columns(name: "user_#{user.id}")
        post anonymize_admin_user_path(user)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:alert]).to eq("User account has already been deleted")
      end

      it "deletes the user account and redirects with a notice" do
        target = user
        original_name = target.name
        post anonymize_admin_user_path(target)
        expect(response).to redirect_to(user_path(target))
        expect(flash[:notice]).to eq("User account '#{original_name}' deleted successfully")
      end

      it "redirects with an alert on UserDeletion::ValidationError" do
        deletion_spy = instance_spy(UserDeletion)
        allow(deletion_spy).to receive(:delete!).and_raise(UserDeletion::ValidationError, "Cannot delete this account")
        allow(UserDeletion).to receive(:new).and_return(deletion_spy)
        post anonymize_admin_user_path(user)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:alert]).to eq("Cannot delete this account")
      end
    end
  end
end
