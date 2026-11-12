# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDeletion do
  include_context "as admin"

  let(:password) { "hexerade" }

  describe "#delete!" do
    context "when deleting own account (admin_deletion: false)" do
      subject(:deletion) { described_class.new(user, password) }

      let(:user) { create(:user) }

      it "renames the user to user_{id}" do
        deletion.delete!
        expect(user.reload.name).to eq("user_#{user.id}")
      end

      it "creates a UserNameChangeRequest recording the rename" do
        original_name = user.name
        expect { deletion.delete! }.to change(UserNameChangeRequest, :count).by(1)
        req = UserNameChangeRequest.last
        expect(req.original_name).to eq(original_name)
        expect(req.desired_name).to eq("user_#{user.id}")
        expect(req.change_reason).to eq("User deletion")
      end

      it "clears email, tags, profile fields, and resets level to MEMBER" do
        deletion.delete!
        user.reload
        expect(user.email).to eq("")
        expect(user.recent_tags).to eq("")
        expect(user.favorite_tags).to eq("")
        expect(user.blacklisted_tags).to eq("")
        expect(user.profile_about).to eq("")
        expect(user.profile_artinfo).to eq("")
        expect(user.custom_style).to eq("")
        expect(user.level).to eq(UserLevel::MEMBER)
      end

      it "does not change the user's level if they are blocked" do
        user.update_columns(level: UserLevel::BLOCKED)
        create(:ban, user: user, prevent_login: false)
        deletion.delete!
        expect(user.reload.level).to eq(UserLevel::BLOCKED)
      end

      it "invalidates the password hash" do
        deletion.delete!
        user.reload
        expect(user.password_hash).to eq("")
        expect(user.bcrypt_password_hash).to eq("*LK*")
      end

      it "deletes outstanding password reset nonces so a pre-requested link cannot revive the account" do
        nonce = create(:user_password_reset_nonce, user: user)
        other = create(:user_password_reset_nonce)
        deletion.delete!
        expect(UserPasswordResetNonce.where(id: nonce.id)).not_to exist
        expect(UserPasswordResetNonce.where(id: other.id)).to exist
        expect(user.reload.bcrypt_password_hash).to eq("*LK*")
      end

      it "logs a :user_delete ModAction" do
        deletion.delete!
        expect(ModAction.last.action).to eq("user_delete")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "enqueues FlushFavoritesJob with the user's id" do
        expect { deletion.delete! }.to enqueue_sidekiq_job(FlushFavoritesJob).with(user.id)
      end

      it "enqueues AvatarCleanupJob with force" do
        expect { deletion.delete! }.to enqueue_sidekiq_job(AvatarCleanupJob).with(user.id, true)
      end

      it "deletes the user's API keys so they no longer authenticate" do
        key = create(:api_key, user: user)
        create(:expiring_api_key, user: user)
        deletion.delete!
        expect(user.api_keys.count).to eq(0)
        expect(User.authenticate_api_key("user_#{user.id}", key.key)).to be_nil
      end

      it "removes TOTP enrollment" do
        create(:user_totp, user: user)
        expect(user.reload.totp_enabled?).to be true
        deletion.delete!
        expect(UserTotp.where(user_id: user.id)).not_to exist
        expect(user.reload.totp_enabled?).to be false
      end

      it "clears privilege and preference flags but keeps restrictions" do
        user.update!(can_approve_posts: true, oauth_applications_beta: true, is_bd_staff: true,
                     enable_safe_mode: true, no_uploading: true, no_flagging: true, no_karma_free: true)
        deletion.delete!
        user.reload
        expect(user.can_approve_posts?).to be false
        expect(user.oauth_applications_beta?).to be false
        expect(user.is_bd_staff?).to be false
        expect(user.enable_safe_mode?).to be false
        expect(user.no_uploading?).to be true
        expect(user.no_flagging?).to be true
        expect(user.no_karma_free?).to be true
      end

      it "enables privacy mode so favorites stay hidden while they are flushed" do
        deletion.delete!
        user.reload
        expect(user.enable_privacy_mode?).to be true
        CurrentUser.user = create(:user)
        expect(user.hide_favorites?).to be true
      end

      it "leaves the passed-in user object current" do
        user.update!(can_approve_posts: true)
        deletion.delete!
        expect(user.can_approve_posts?).to be false
      end

      context "when a step fails partway through" do
        before { allow(user).to receive(:revoke_oauth_credentials!).and_raise(ActiveRecord::StatementInvalid) }

        it "rolls back so the deletion can be retried" do
          original_name = user.name
          key = create(:api_key, user: user)
          expect { deletion.delete! }.to raise_error(ActiveRecord::StatementInvalid)
          user.reload
          expect(user.name).to eq(original_name)
          expect(user.bcrypt_password_hash).not_to eq("*LK*")
          expect(ApiKey.exists?(key.id)).to be true
          expect(UserNameChangeRequest.where(user_id: user.id)).not_to exist
        end

        it "expires the name cache entries written by the rolled-back rename" do
          allow(Cache).to receive(:delete).and_call_original
          expect { deletion.delete! }.to raise_error(ActiveRecord::StatementInvalid)
          expect(Cache).to have_received(:delete).with("uin:#{user.id}")
          expect(Cache).to have_received(:delete).with("uni:user_#{user.id}")
        end

        it "does not enqueue cleanup jobs" do
          expect { deletion.delete! }.to raise_error(ActiveRecord::StatementInvalid)
          expect(AvatarCleanupJob.jobs).to be_empty
          expect(FlushFavoritesJob.jobs).to be_empty
        end
      end

      describe "OAuth credentials" do
        let(:other_user) { create(:user) }
        let(:other_app) do
          Doorkeeper::Application.create!(
            name: "other-app", redirect_uri: "http://localhost/cb",
            scopes: "openid full", owner: other_user
          )
        end
        let(:owned_app) do
          Doorkeeper::Application.create!(
            name: "owned-by-deleted-user", redirect_uri: "http://localhost/cb",
            scopes: "openid full", owner: user
          )
        end

        it "revokes tokens and grants the user holds on other apps" do
          token = Doorkeeper::AccessToken.create!(application: other_app, resource_owner_id: user.id, scopes: "openid full")
          grant = Doorkeeper::AccessGrant.create!(
            application: other_app, resource_owner_id: user.id, scopes: "openid full",
            expires_in: 600, redirect_uri: "http://localhost/cb"
          )
          deletion.delete!
          expect(token.reload.revoked?).to be true
          expect(grant.reload.revoked?).to be true
        end

        it "revokes tokens issued by apps the user owns, keeping the app row" do
          token = Doorkeeper::AccessToken.create!(application: owned_app, resource_owner_id: other_user.id, scopes: "openid full")
          deletion.delete!
          expect(token.reload.revoked?).to be true
          expect(Doorkeeper::Application.exists?(owned_app.id)).to be true
        end

        it "does not touch other users' unrelated tokens" do
          unrelated = Doorkeeper::AccessToken.create!(application: other_app, resource_owner_id: other_user.id, scopes: "openid full")
          deletion.delete!
          expect(unrelated.reload.revoked?).to be false
        end
      end
    end

    context "when the user is already named user_{id}" do
      subject(:deletion) { described_class.new(user, password) }

      let(:user) { create(:user) }

      before { user.update_columns(name: "user_#{user.id}") }

      it "does not create a UserNameChangeRequest" do
        expect { deletion.delete! }.not_to change(UserNameChangeRequest, :count)
      end
    end

    context "when admin deletes a member account (admin_deletion: true)" do
      subject(:deletion) { described_class.new(user, nil, admin_deletion: true) }

      let(:user) { create(:user) }

      it "renames the user to user_{id}" do
        deletion.delete!
        expect(user.reload.name).to eq("user_#{user.id}")
      end

      it "logs an :admin_user_delete ModAction" do
        deletion.delete!
        expect(ModAction.last.action).to eq("admin_user_delete")
        expect(ModAction.last[:values]).to include("user_id" => user.id)
      end

      it "creates a UserNameChangeRequest with reason 'Administrative deletion'" do
        deletion.delete!
        expect(UserNameChangeRequest.last.change_reason).to eq("Administrative deletion")
      end

      it "enqueues FlushFavoritesJob" do
        expect { deletion.delete! }.to enqueue_sidekiq_job(FlushFavoritesJob).with(user.id)
      end

      it "deletes the user's API keys" do
        create(:api_key, user: user)
        deletion.delete!
        expect(user.api_keys.count).to eq(0)
      end

      it "revokes OAuth tokens and clears grant flags" do
        user.update!(oauth_applications_beta: true)
        app = Doorkeeper::Application.create!(
          name: "admin-deleted-app", redirect_uri: "http://localhost/cb",
          scopes: "openid full", owner: create(:user)
        )
        token = Doorkeeper::AccessToken.create!(application: app, resource_owner_id: user.id, scopes: "openid full")
        deletion.delete!
        expect(token.reload.revoked?).to be true
        expect(user.reload.oauth_applications_beta?).to be false
      end
    end

    context "validation" do
      it "raises ValidationError for a forcibly logged out banned user doing self-deletion" do
        user = create(:user)
        create(:hard_ban, user: user)
        expect { described_class.new(user, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /Banned users/)
      end

      it "does not raise a ValidationError for a soft-banned user doing self-deletion" do
        user = create(:user)
        create(:ban, user: user, prevent_login: false)
        expect { described_class.new(user, password).delete! }
          .not_to raise_error
      end

      it "raises ValidationError when the account is less than one week old" do
        user = create(:user, created_at: 1.day.ago)
        expect { described_class.new(user, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /one week old/)
      end

      it "raises ValidationError when the password is incorrect" do
        user = create(:user)
        expect { described_class.new(user, "wrongpassword").delete! }
          .to raise_error(UserDeletion::ValidationError, /Password is incorrect/)
      end

      it "raises ValidationError for an admin trying to delete their own account" do
        admin = create(:admin_user)
        expect { described_class.new(admin, password).delete! }
          .to raise_error(UserDeletion::ValidationError, /Admins cannot delete/)
      end

      it "raises ValidationError when admin_deletion targets a janitor" do
        staff = create(:janitor_user)
        expect { described_class.new(staff, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Staff accounts/)
      end

      it "raises ValidationError when admin_deletion targets a moderator" do
        staff = create(:moderator_user)
        expect { described_class.new(staff, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Staff accounts/)
      end

      it "raises ValidationError when admin_deletion targets an admin" do
        admin = create(:admin_user)
        expect { described_class.new(admin, nil, admin_deletion: true).delete! }
          .to raise_error(UserDeletion::ValidationError, /Admins cannot delete/)
      end
    end

    context "name collision" do
      it "falls back to user_{id}_1 when user_{id} is already taken by another user" do
        target = create(:user)
        squatter = create(:user)
        squatter.update_columns(name: "user_#{target.id}")

        described_class.new(target, password).delete!
        expect(target.reload.name).to eq("user_#{target.id}_1")
      end
    end
  end
end
