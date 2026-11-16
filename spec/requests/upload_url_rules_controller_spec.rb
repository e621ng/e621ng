# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadUrlRulesController do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:staff)  { create(:staff_user) }
  let(:member) { create(:user) }
  let!(:rule)  { create(:upload_url_rule, label: "Sample URL") }
  let(:valid_params) { { upload_url_rule: { label: "Thumbnail", pattern: "example\\.com/thumb/", replacement: "example.com/full/", handling: "block", message: "", enabled: true } } }

  describe "GET /upload_url_rules" do
    it "redirects anonymous users to the login page" do
      get upload_url_rules_path
      expect(response).to redirect_to(new_session_path(url: upload_url_rules_path))
    end

    it "lists rules for a member, without edit links" do
      sign_in_as member
      get upload_url_rules_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sample URL")
      expect(response.body).not_to include(edit_upload_url_rule_path(rule))
    end

    it "shows edit links to staff" do
      sign_in_as staff
      get upload_url_rules_path
      expect(response.body).to include(edit_upload_url_rule_path(rule))
    end

    it "returns JSON for a member" do
      sign_in_as member
      get upload_url_rules_path(format: :json)
      expect(response.parsed_body.first).to include("label" => "Sample URL", "handling" => "recommend")
    end

    it "filters by handling" do
      sign_in_as member
      get upload_url_rules_path(format: :json), params: { search: { handling: "block" } }
      expect(response.parsed_body).to be_empty
    end
  end

  describe "GET /upload_url_rules/new and edit" do
    it "is forbidden for a member" do
      sign_in_as member
      get new_upload_url_rule_path
      expect(response).to have_http_status(:forbidden)
      get edit_upload_url_rule_path(rule)
      expect(response).to have_http_status(:forbidden)
    end

    it "renders for staff" do
      sign_in_as staff
      get new_upload_url_rule_path
      expect(response).to have_http_status(:ok)
      get edit_upload_url_rule_path(rule)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /upload_url_rules" do
    it "is forbidden for a member" do
      sign_in_as member
      expect { post upload_url_rules_path, params: valid_params }.not_to change(UploadUrlRule, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a rule for staff and logs it" do
      sign_in_as staff
      expect { post upload_url_rules_path, params: valid_params }.to change(UploadUrlRule, :count).by(1)
      expect(response).to redirect_to(upload_url_rules_path)
      expect(UploadUrlRule.last).to have_attributes(label: "Thumbnail", handling: "block", creator_id: staff.id, updater_id: staff.id)
      expect(ModAction.last).to have_attributes(action: "upload_url_rule_create", creator_id: staff.id)
    end

    it "re-renders the form for an invalid rule" do
      sign_in_as staff
      expect { post upload_url_rules_path, params: { upload_url_rule: valid_params[:upload_url_rule].merge(pattern: "(") } }.not_to change(UploadUrlRule, :count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("is invalid")
    end

    it "tests without saving when submitted with the Test button" do
      sign_in_as staff
      expect do
        post upload_url_rules_path, params: valid_params.merge(commit: "Test", test_url: "HTTPS://example.com/thumb/1.jpg#x")
      end.not_to change(UploadUrlRule, :count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://example.com/thumb/1.jpg", "https://example.com/full/1.jpg")
    end

    it "reports a non-matching test URL" do
      sign_in_as staff
      post upload_url_rules_path, params: valid_params.merge(commit: "Test", test_url: "https://example.com/other/1.jpg")
      expect(response.body).to include("No match.")
    end
  end

  describe "PATCH /upload_url_rules/:id" do
    it "is forbidden for a member" do
      sign_in_as member
      patch upload_url_rule_path(rule), params: { upload_url_rule: { handling: "block" } }
      expect(response).to have_http_status(:forbidden)
      expect(rule.reload.handling).to eq("recommend")
    end

    it "updates the rule for staff" do
      sign_in_as staff
      patch upload_url_rule_path(rule), params: { upload_url_rule: { handling: "block" } }
      expect(response).to redirect_to(upload_url_rules_path)
      expect(rule.reload).to have_attributes(handling: "block", updater_id: staff.id)
    end

    it "does not save when submitted with the Test button" do
      sign_in_as staff
      patch upload_url_rule_path(rule), params: { upload_url_rule: { handling: "block" }, commit: "Test", test_url: "https://example.com/sample/1.jpg" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://example.com/full/1.jpg")
      expect(rule.reload.handling).to eq("recommend")
    end
  end

  describe "DELETE /upload_url_rules/:id" do
    it "is forbidden for a member" do
      sign_in_as member
      expect { delete upload_url_rule_path(rule) }.not_to change(UploadUrlRule, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "deletes the rule for staff" do
      sign_in_as staff
      expect { delete upload_url_rule_path(rule) }.to change(UploadUrlRule, :count).by(-1)
    end
  end

  describe "GET /upload_url_rules/check" do
    let(:url) { "https://example.com/sample/1.jpg" }

    it "is forbidden for anonymous users" do
      get check_upload_url_rules_path(format: :json), params: { url: url }
      expect(response).to have_http_status(:forbidden)
    end

    it "reports a match with the suggestion" do
      sign_in_as member
      get check_upload_url_rules_path(format: :json), params: { url: url }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "match" => true,
        "handling" => "recommend",
        "label" => "Sample URL",
        "message" => "",
        "suggested_url" => "https://example.com/full/1.jpg",
        "canonical_url" => url,
      )
    end

    it "reports no match" do
      sign_in_as member
      get check_upload_url_rules_path(format: :json), params: { url: "https://example.com/full/1.jpg" }
      expect(response.parsed_body).to eq("match" => false)
    end

    it "reports no match for a missing or non-string url" do
      sign_in_as member
      get check_upload_url_rules_path(format: :json)
      expect(response.parsed_body).to eq("match" => false)
      get check_upload_url_rules_path(format: :json), params: { url: { nested: "value" } }
      expect(response.parsed_body).to eq("match" => false)
    end

    it "responds 422 rule_failed when a rule cannot be evaluated" do
      sign_in_as member
      allow(UploadUrlRule).to receive(:evaluate).and_raise(UploadUrlRule::EvaluationError.new("Slow"))
      get check_upload_url_rules_path(format: :json), params: { url: url }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "rule_failed", "label" => "Slow")
    end

    it "is throttled" do
      sign_in_as member
      allow(RateLimiter).to receive(:throttle!).and_return(true)
      get check_upload_url_rules_path(format: :json), params: { url: url }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
