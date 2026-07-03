# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::AutomodRulesController do
  let(:admin) { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member) { create(:user) }
  let!(:rule) { create(:automod_rule, name: "test_rule", regex: "spam") }

  # ---------------------------------------------------------------------------
  # GET /staff/automod/rules
  # ---------------------------------------------------------------------------
  describe "#index" do
    it "render for an admin" do
      sign_in_as admin
      get staff_automod_rules_path
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get staff_automod_rules_path
      expect(response).to have_http_status(:forbidden)
    end

    it "be forbidden for a member" do
      sign_in_as member
      get staff_automod_rules_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/automod/rules/new
  # ---------------------------------------------------------------------------

  describe "#new" do
    it "render for an admin" do
      sign_in_as admin
      get new_staff_automod_rule_path
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get new_staff_automod_rule_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/automod/rules
  # ---------------------------------------------------------------------------

  describe "#create" do
    it "create a rule for an admin" do
      expect do
        sign_in_as admin
        post staff_automod_rules_path, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } }
      end.to change(AutomodRule, :count).by(1)
      expect(response).to redirect_to(staff_automod_rules_path)
      expect(AutomodRule.last.creator).to eq(admin)
    end

    it "be forbidden for a moderator" do
      expect do
        sign_in_as moderator
        post staff_automod_rules_path, params: { automod_rule: { name: "new_rule", regex: "badword", enabled: true } }
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "re-render new with validation errors" do
      expect do
        sign_in_as admin
        post staff_automod_rules_path, params: { automod_rule: { name: "", regex: "badword", enabled: true } }
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:success)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/automod/rules/:id/edit
  # ---------------------------------------------------------------------------

  describe "#edit" do
    it "render for an admin" do
      sign_in_as admin
      get edit_staff_automod_rule_path(rule)
      expect(response).to have_http_status(:success)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      get edit_staff_automod_rule_path(rule)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /staff/automod/rules/:id
  # ---------------------------------------------------------------------------

  describe "#update" do
    it "update a rule for an admin" do
      sign_in_as admin
      patch staff_automod_rule_path(rule), params: { automod_rule: { name: "updated_rule", regex: "newpattern", enabled: false } }
      expect(response).to redirect_to(staff_automod_rules_path)
      rule.reload
      expect(rule.name).to eq("updated_rule")
      expect(rule.regex).to eq("newpattern")
      expect(rule.enabled?).to be(false)
    end

    it "be forbidden for a moderator" do
      sign_in_as moderator
      patch staff_automod_rule_path(rule), params: { automod_rule: { name: "updated_rule" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /staff/automod/rules/:id
  # ---------------------------------------------------------------------------

  describe "#destroy" do
    it "delete a rule for an admin" do
      expect do
        sign_in_as admin
        delete staff_automod_rule_path(rule)
      end.to change(AutomodRule, :count).by(-1)
      expect(response).to redirect_to(staff_automod_rules_path)
    end

    it "be forbidden for a moderator" do
      expect do
        sign_in_as moderator
        delete staff_automod_rule_path(rule)
      end.not_to change(AutomodRule, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
