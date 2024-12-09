# frozen_string_literal: true

require "test_helper"

module Security
  class LockdownControllerTest < ActionDispatch::IntegrationTest
    context "The lockdown controller" do
      setup do
        @admin = create(:admin_user)
      end

      teardown do
        Security::Lockdown.uploads_min_level = User::Levels::MEMBER
        Security::Lockdown.hide_pending_posts_for = 0
      end

      context "index action" do
        should "render" do
          get_auth security_root_path, @admin
          assert_response :success
        end
      end

      context "uploading limits action" do
        should "work" do
          put_auth uploads_min_level_security_lockdown_index_path, @admin, params: { uploads_min_level: { min_level: User::Levels::PRIVILEGED } }
          assert_equal Security::Lockdown.uploads_min_level, User::Levels::PRIVILEGED
        end
      end

      context "hide pending posts action" do
        should "work" do
          put_auth uploads_hide_pending_security_lockdown_index_path, @admin, params: { uploads_hide_pending: { duration: 24 } }
          assert_equal Security::Lockdown.hide_pending_posts_for, 24
        end
      end
    end
  end
end
