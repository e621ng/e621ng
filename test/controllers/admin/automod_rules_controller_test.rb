# frozen_string_literal: true

require "test_helper"

class Admin::AutomodRulesControllerTest < ActionDispatch::IntegrationTest
  context "The admin automod rules controller" do
    setup do
      @admin = create(:admin_user)
      @moderator = create(:moderator_user)
      @member = create(:user)
      @rule = create(:automod_rule, name: "test_rule", regex: "spam")
    end

    context "index action" do
      should "render for an admin" do
        get_auth(admin_automod_rules_path, @admin)
        assert_response(:success)
      end

      should "be forbidden for a moderator" do
        get_auth(admin_automod_rules_path, @moderator)
        assert_response(:forbidden)
      end

      should "be forbidden for a member" do
        get_auth(admin_automod_rules_path, @member)
        assert_response(:forbidden)
      end
    end

    context "new action" do
      should "render for an admin" do
        get_auth(new_admin_automod_rule_path, @admin)
        assert_response(:success)
      end

      should "be forbidden for a moderator" do
        get_auth(new_admin_automod_rule_path, @moderator)
        assert_response(:forbidden)
      end
    end

    context "create action" do
      should "create a rule for an admin" do
        assert_difference("AutomodRule.count", 1) do
          post_auth(admin_automod_rules_path, @admin, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } })
        end
        assert_redirected_to(admin_automod_rules_path)
        assert_equal(@admin, AutomodRule.last.creator)
      end

      should "be forbidden for a moderator" do
        assert_no_difference("AutomodRule.count") do
          post_auth(admin_automod_rules_path, @moderator, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } })
        end
        assert_response(:forbidden)
      end

      should "re-render new with validation errors" do
        assert_no_difference("AutomodRule.count") do
          post_auth(admin_automod_rules_path, @admin, params: { automod_rule: { name: "", regex: "badword", enabled: true } })
        end
        assert_response(:success)
      end
    end

    context "edit action" do
      should "render for an admin" do
        get_auth(edit_admin_automod_rule_path(@rule), @admin)
        assert_response(:success)
      end

      should "be forbidden for a moderator" do
        get_auth(edit_admin_automod_rule_path(@rule), @moderator)
        assert_response(:forbidden)
      end
    end

    context "update action" do
      should "update a rule for an admin" do
        patch_auth(admin_automod_rule_path(@rule), @admin, params: { automod_rule: { name: "updated_rule", regex: "newpattern", enabled: false } })
        assert_redirected_to(admin_automod_rules_path)
        @rule.reload
        assert_equal("updated_rule", @rule.name)
        assert_equal("newpattern", @rule.regex)
        assert_not(@rule.enabled?)
      end

      should "be forbidden for a moderator" do
        patch_auth(admin_automod_rule_path(@rule), @moderator, params: { automod_rule: { name: "updated_rule" } })
        assert_response(:forbidden)
      end
    end

    context "destroy action" do
      should "delete a rule for an admin" do
        assert_difference("AutomodRule.count", -1) do
          delete_auth(admin_automod_rule_path(@rule), @admin)
        end
        assert_redirected_to(admin_automod_rules_path)
      end

      should "be forbidden for a moderator" do
        assert_no_difference("AutomodRule.count") do
          delete_auth(admin_automod_rule_path(@rule), @moderator)
        end
        assert_response(:forbidden)
      end
    end
  end
end
