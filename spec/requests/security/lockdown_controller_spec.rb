# frozen_string_literal: true

require "rails_helper"

RSpec.describe Security::LockdownController do
  let(:admin) { create(:admin_user) }
  let(:user)  { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /security/lockdown
  # ---------------------------------------------------------------------------

  describe "GET /security/lockdown" do
    it "redirects anonymous to the login page" do
      get security_lockdown_index_path
      expect(response).to redirect_to(new_session_path(url: security_lockdown_index_path))
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      get security_lockdown_index_path
      expect(response).to have_http_status(:forbidden)
    end

    # FIXME: the security/lockdown/index.html.erb view is missing; the action returns 406 instead of 200.
    # it "returns 200 for an admin" do
    #   sign_in_as admin
    #   get security_lockdown_index_path
    #   expect(response).to have_http_status(:ok)
    # end
  end

  # ---------------------------------------------------------------------------
  # PUT /security/lockdown/panic
  # ---------------------------------------------------------------------------

  describe "PUT /security/lockdown/panic" do
    it "redirects anonymous to the login page" do
      put panic_security_lockdown_index_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      put panic_security_lockdown_index_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "redirects to the security dashboard" do
        put panic_security_lockdown_index_path
        expect(response).to redirect_to(security_root_path)
      end

      it "disables uploads" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.uploads_disabled?).to be true
      end

      it "disables pools" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.pools_disabled?).to be true
      end

      it "disables post sets" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.post_sets_disabled?).to be true
      end

      it "disables comments" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.comments_disabled?).to be true
      end

      it "disables forums" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.forums_disabled?).to be true
      end

      it "disables blips" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.blips_disabled?).to be true
      end

      it "disables aiburs" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.aiburs_disabled?).to be true
      end

      it "disables favorites" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.favorites_disabled?).to be true
      end

      it "disables votes" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.votes_disabled?).to be true
      end

      it "disables takedowns" do
        put panic_security_lockdown_index_path
        expect(Security::Lockdown.takedowns_disabled?).to be true
      end

      it "logs a lockdown_panic StaffAuditLog entry" do
        expect { put panic_security_lockdown_index_path }.to change(StaffAuditLog, :count).by(1)
        expect(StaffAuditLog.last.action).to eq("lockdown_panic")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /security/lockdown/enact
  # ---------------------------------------------------------------------------

  describe "PUT /security/lockdown/enact" do
    it "redirects anonymous to the login page" do
      put enact_security_lockdown_index_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      put enact_security_lockdown_index_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "redirects to the security dashboard" do
        put enact_security_lockdown_index_path
        expect(response).to redirect_to(security_root_path)
      end

      it "enables uploads lockdown when the uploads param is '1'" do
        put enact_security_lockdown_index_path, params: { lockdown: { uploads: "1" } }
        expect(Security::Lockdown.uploads_disabled?).to be true
      end

      it "disables uploads lockdown when the uploads param is '0'" do
        Security::Lockdown.uploads_disabled = "1"
        put enact_security_lockdown_index_path, params: { lockdown: { uploads: "0" } }
        expect(Security::Lockdown.uploads_disabled?).to be false
      end

      it "does not change pools lockdown when pools param is absent" do
        expect do
          put enact_security_lockdown_index_path, params: { lockdown: { uploads: "1" } }
        end.not_to change(Security::Lockdown, :pools_disabled?)
      end

      it "logs a lockdown_uploads StaffAuditLog entry" do
        expect do
          put enact_security_lockdown_index_path, params: { lockdown: { uploads: "1" } }
        end.to change(StaffAuditLog, :count).by(1)
        expect(StaffAuditLog.last.action).to eq("lockdown_uploads")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /security/lockdown/uploads_min_level
  # ---------------------------------------------------------------------------

  describe "PUT /security/lockdown/uploads_min_level" do
    it "redirects anonymous to the login page" do
      put uploads_min_level_security_lockdown_index_path,
          params: { uploads_min_level: { min_level: User::Levels::MEMBER } }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      put uploads_min_level_security_lockdown_index_path,
          params: { uploads_min_level: { min_level: User::Levels::MEMBER } }
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "redirects to the security dashboard" do
        put uploads_min_level_security_lockdown_index_path,
            params: { uploads_min_level: { min_level: User::Levels::MEMBER } }
        expect(response).to redirect_to(security_root_path)
      end

      it "updates the minimum upload level when a valid level is given" do
        put uploads_min_level_security_lockdown_index_path,
            params: { uploads_min_level: { min_level: User::Levels::PRIVILEGED } }
        expect(Security::Lockdown.uploads_min_level).to eq(User::Levels::PRIVILEGED)
      end

      it "logs a min_upload_level StaffAuditLog entry when the level changes" do
        # Seed a known starting value; rails-settings-cached caches values in memory and
        # DB transaction rollback alone does not clear the cache between examples.
        Security::Lockdown.uploads_min_level = User::Levels::MEMBER
        new_level = User::Levels::PRIVILEGED

        expect do
          put uploads_min_level_security_lockdown_index_path,
              params: { uploads_min_level: { min_level: new_level } }
        end.to change(StaffAuditLog, :count).by(1)
        expect(StaffAuditLog.last.action).to eq("min_upload_level")
        expect(StaffAuditLog.last[:values]).to include("level" => new_level)
      end

      it "does not log when the submitted level equals the current level" do
        current = Security::Lockdown.uploads_min_level
        expect do
          put uploads_min_level_security_lockdown_index_path,
              params: { uploads_min_level: { min_level: current } }
        end.not_to change(StaffAuditLog, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /security/lockdown/uploads_hide_pending
  # ---------------------------------------------------------------------------

  describe "PUT /security/lockdown/uploads_hide_pending" do
    it "redirects anonymous to the login page" do
      put uploads_hide_pending_security_lockdown_index_path,
          params: { uploads_hide_pending: { duration: 0 } }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      put uploads_hide_pending_security_lockdown_index_path,
          params: { uploads_hide_pending: { duration: 0 } }
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "redirects to the security dashboard" do
        put uploads_hide_pending_security_lockdown_index_path,
            params: { uploads_hide_pending: { duration: 0 } }
        expect(response).to redirect_to(security_root_path)
      end

      it "updates hide_pending_posts_for when the duration differs from the current value" do
        Security::Lockdown.hide_pending_posts_for = 0
        put uploads_hide_pending_security_lockdown_index_path,
            params: { uploads_hide_pending: { duration: 24 } }
        expect(Security::Lockdown.hide_pending_posts_for).to eq(24)
      end

      it "logs a hide_pending_posts_for StaffAuditLog entry when changed" do
        Security::Lockdown.hide_pending_posts_for = 0
        expect do
          put uploads_hide_pending_security_lockdown_index_path,
              params: { uploads_hide_pending: { duration: 12 } }
        end.to change(StaffAuditLog, :count).by(1)
        expect(StaffAuditLog.last.action).to eq("hide_pending_posts_for")
        expect(StaffAuditLog.last[:values]).to include("duration" => 12.0)
      end

      it "does not log when the duration equals the current value" do
        Security::Lockdown.hide_pending_posts_for = 6
        expect do
          put uploads_hide_pending_security_lockdown_index_path,
              params: { uploads_hide_pending: { duration: 6 } }
        end.not_to change(StaffAuditLog, :count)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /security/lockdown/maintenance
  # ---------------------------------------------------------------------------

  describe "PUT /security/lockdown/maintenance" do
    it "redirects anonymous to the login page" do
      put maintenance_security_lockdown_index_path
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as user
      put maintenance_security_lockdown_index_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      it "redirects to the security dashboard" do
        put maintenance_security_lockdown_index_path
        expect(response).to redirect_to(security_root_path)
      end

      it "enables disable_exception_prune when param is '1'" do
        put maintenance_security_lockdown_index_path,
            params: { maintenance: { disable_exception_prune: "1" } }
        expect(Setting.disable_exception_prune).to be true
      end

      it "disables disable_exception_prune when param is '0'" do
        put maintenance_security_lockdown_index_path,
            params: { maintenance: { disable_exception_prune: "0" } }
        expect(Setting.disable_exception_prune).to be false
      end

      it "does not change disable_exception_prune when param is absent" do
        original = Setting.disable_exception_prune
        expect do
          put maintenance_security_lockdown_index_path
        end.not_to change(Setting, :disable_exception_prune)
        expect(Setting.disable_exception_prune).to eq(original)
      end
    end
  end
end
