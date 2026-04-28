# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::AutomodRulesController do
  let(:admin) { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member) { create(:user) }
  let!(:rule) { create(:automod_rule, name: "test_rule", regex: "spam") }

  describe "#index" do
    it "render for an admin" do
      sign_in_as admin
      get admin_automod_rules_path
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get admin_automod_rules_path
      expect(response).to have_http_status(:forbidden)
    end

    it "be forbidden for a member" do
      sign_in_as member
      get admin_automod_rules_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#new" do
    it "render for an admin" do
      sign_in_as admin
      get new_admin_automod_rule_path
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get new_admin_automod_rule_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#create" do
    it "create a rule for an admin" do
      expect do
        sign_in_as admin
        post admin_automod_rules_path, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } }
      end.to change(AutomodRule, :count).by(1)
      expect(response).to redirect_to(admin_automod_rules_path)
      expect(AutomodRule.last.creator).to eq(admin)
    end

    it "be forbidden for a moderator" do
      expect do
        sign_in_as moderator
        post admin_automod_rules_path, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } }
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "re-render new with validation errors" do
      expect do
        sign_in_as admin
        post admin_automod_rules_path, params: { automod_rule: { name: "", regex: "badword", enabled: true } }
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:success)
    end
  end

  describe "#edit" do
    it "render for an admin" do
      sign_in_as admin
      get edit_admin_automod_rule_path(rule)
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get edit_admin_automod_rule_path(rule)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#update" do
    it "update a rule for an admin" do
      sign_in_as admin
      patch admin_automod_rule_path(rule), params: { automod_rule: { name: "updated_rule", regex: "newpattern", enabled: false } }
      expect(response).to redirect_to(admin_automod_rules_path)
      rule.reload
      expect(rule.name).to eq("updated_rule")
      expect(rule.regex).to eq("newpattern")
      expect(rule.enabled?).to be(false)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      patch admin_automod_rule_path(rule), params: { automod_rule: { name: "updated_rule" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#destroy" do
    it "delete a rule for an admin" do
      expect do
        sign_in_as admin
        delete admin_automod_rule_path(rule)
      end.to change(AutomodRule, :count).by(-1)
      expect(response).to redirect_to(admin_automod_rules_path)
    end

    it "be forbidden for a moderator" do
      expect do
        sign_in_as moderator
        delete admin_automod_rule_path(rule)
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
