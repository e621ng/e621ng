# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AutomodRulesController do
  let(:admin) { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member) { create(:user) }
  let!(:rule) { create(:automod_rule, name: "test_rule", regex: "spam") }

  describe "#index" do
    it "render for an admin" do
      get_auth(admin_automod_rules_path, admin)
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      get_auth(admin_automod_rules_path, moderator)
      expect(response).to have_http_status(:forbidden)
    end

    it "be forbidden for a member" do
      get_auth(admin_automod_rules_path, member)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#new" do
    it "render for an admin" do
      get_auth(new_admin_automod_rule_path, admin)
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      get_auth(new_admin_automod_rule_path, moderator)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#create" do
    it "create a rule for an admin" do
      expect do
        post_auth(admin_automod_rules_path, admin, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } })
      end.to change(AutomodRule, :count).by(1)
      expect(response).to redirect_to(admin_automod_rules_path)
      expect(AutomodRule.last.creator).to eq(admin)
    end

    it "be forbidden for a moderator" do
      expect do
        post_auth(admin_automod_rules_path, moderator, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } })
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "re-render new with validation errors" do
      expect do
        post_auth(admin_automod_rules_path, admin, params: { automod_rule: { name: "", regex: "badword", enabled: true } })
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:success)
    end
  end

  describe "#edit" do
    it "render for an admin" do
      get_auth(edit_admin_automod_rule_path(rule), admin)
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      get_auth(edit_admin_automod_rule_path(rule), moderator)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#update" do
    it "update a rule for an admin" do
      patch_auth(admin_automod_rule_path(rule), admin, params: { automod_rule: { name: "updated_rule", regex: "newpattern", enabled: false } })
      expect(response).to redirect_to(admin_automod_rules_path)
      rule.reload
      expect(rule.name).to eq("updated_rule")
      expect(rule.regex).to eq("newpattern")
      expect(rule.enabled?).to be(false)
    end

    it "be forbidden for a moderator" do
      patch_auth(admin_automod_rule_path(rule), moderator, params: { automod_rule: { name: "updated_rule" } })
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#destroy" do
    it "delete a rule for an admin" do
      expect do
        delete_auth(admin_automod_rule_path(rule), admin)
      end.to change(AutomodRule, :count).by(-1)
      expect(response).to redirect_to(admin_automod_rules_path)
    end

    it "be forbidden for a moderator" do
      expect do
        delete_auth(admin_automod_rule_path(rule), moderator)
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
