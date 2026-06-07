# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostFlagReasonsController do
  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member)    { create(:user) }
  let!(:reason)   { create(:post_flag_reason) }

  describe "#index" do
    it "renders for an admin" do
      sign_in_as admin
      get post_flag_reasons_path
      expect(response).to have_http_status(:success)
    end

    it "is forbidden for a moderator" do
      sign_in_as moderator
      get post_flag_reasons_path
      expect(response).to have_http_status(:forbidden)
    end

    it "is forbidden for a member" do
      sign_in_as member
      get post_flag_reasons_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#new" do
    it "renders for an admin" do
      sign_in_as admin
      get new_post_flag_reason_path
      expect(response).to have_http_status(:success)
    end

    it "is forbidden for a moderator" do
      sign_in_as moderator
      get new_post_flag_reason_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#edit" do
    it "renders for an admin" do
      sign_in_as admin
      get edit_post_flag_reason_path(reason)
      expect(response).to have_http_status(:success)
    end

    it "is forbidden for a moderator" do
      sign_in_as moderator
      get edit_post_flag_reason_path(reason)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#create" do
    let(:valid_params) { { post_flag_reason: { name: "new_reason", reason: "A good reason", text: "Details here", index: 10 } } }
    let(:invalid_params) { { post_flag_reason: { name: "", reason: "A good reason", index: 10 } } }

    it "creates a reason for an admin" do
      expect do
        sign_in_as admin
        post post_flag_reasons_path, params: valid_params
      end.to change(PostFlagReason, :count).by(1)
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to eq("Post flag reason created")
    end

    it "logs a ModAction on create" do
      sign_in_as admin
      post post_flag_reasons_path, params: valid_params
      expect(ModAction.last.action).to eq("flag_reason_create")
      expect(ModAction.last[:values]).to include("reason" => "A good reason", "text" => "Details here")
    end

    it "does not create with invalid params" do
      expect do
        sign_in_as admin
        post post_flag_reasons_path, params: invalid_params
      end.not_to change(PostFlagReason, :count)
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to include("can't be blank")
    end

    it "is forbidden for a moderator" do
      expect do
        sign_in_as moderator
        post post_flag_reasons_path, params: valid_params
      end.not_to change(PostFlagReason, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#update" do
    let(:valid_params) { { post_flag_reason: { reason: "Updated reason text" } } }
    let(:invalid_params) { { post_flag_reason: { name: "" } } }

    it "updates a reason for an admin" do
      sign_in_as admin
      patch post_flag_reason_path(reason), params: valid_params
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to eq("Post flag reason updated")
      expect(reason.reload.reason).to eq("Updated reason text")
    end

    it "does not update with invalid params" do
      original_name = reason.name
      sign_in_as admin
      patch post_flag_reason_path(reason), params: invalid_params
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to include("can't be blank")
      expect(reason.reload.name).to eq(original_name)
    end

    it "is forbidden for a moderator" do
      sign_in_as moderator
      patch post_flag_reason_path(reason), params: valid_params
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#destroy" do
    it "deletes a reason for an admin" do
      expect do
        sign_in_as admin
        delete post_flag_reason_path(reason)
      end.to change(PostFlagReason, :count).by(-1)
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to eq("Post flag reason deleted")
    end

    it "logs a ModAction on destroy" do
      reason_text = reason.reason
      sign_in_as admin
      delete post_flag_reason_path(reason)
      expect(ModAction.last.action).to eq("flag_reason_delete")
      expect(ModAction.last[:values]).to include("reason" => reason_text)
    end

    it "is forbidden for a moderator" do
      expect do
        sign_in_as moderator
        delete post_flag_reason_path(reason)
      end.not_to change(PostFlagReason, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#clear_cache" do
    it "clears the cache for an admin" do
      sign_in_as admin
      post clear_cache_post_flag_reasons_path
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:notice]).to eq("Post flag reason cache cleared")
    end

    it "is forbidden for a moderator" do
      sign_in_as moderator
      post clear_cache_post_flag_reasons_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#set_ai_flag_reason" do
    let!(:valid_reason) { create(:post_flag_reason, name: "ai_generated", needs_parent_id: false) }

    around do |example|
      original_ai_flag_reason = Setting.ai_flag_reason
      original_automatic_ai_check = Setting.automatic_ai_check
      example.run
    ensure
      Setting.ai_flag_reason = original_ai_flag_reason
      Setting.automatic_ai_check = original_automatic_ai_check
    end

    it "enables AI post flagging with a valid reason for an admin" do
      Setting.automatic_ai_check = false
      sign_in_as admin
      post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: valid_reason.name, automatic_ai_check: "1" } }
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(Setting.automatic_ai_check?).to be(true)
      expect(Setting.ai_flag_reason).to eq(valid_reason.name)
      expect(flash[:notice]).to eq("Automatic AI post flagging enabled")
    end

    it "disables AI post flagging for an admin" do
      Setting.automatic_ai_check = true
      Setting.ai_flag_reason = valid_reason.name
      sign_in_as admin
      post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: valid_reason.name, automatic_ai_check: "0" } }
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(Setting.automatic_ai_check?).to be(false)
      expect(Setting.ai_flag_reason).to eq(valid_reason.name)
      expect(flash[:notice]).to eq("Automatic AI post flagging disabled")
    end

    it "redirects with an alert if the reason does not exist" do
      sign_in_as admin
      expect do
        post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: "non_existent_reason", automatic_ai_check: "1" } }
      end.not_to change(Setting, :automatic_ai_check)
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:alert]).to eq("Flag reason doesn't exist or is not usable for AI flagging")
    end

    it "redirects with an alert if the reason needs a parent id" do
      parent_reason = create(:post_flag_reason, name: "needs_parent", needs_parent_id: true)
      sign_in_as admin
      expect do
        post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: parent_reason.name, automatic_ai_check: "1" } }
      end.not_to change(Setting, :automatic_ai_check)
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(flash[:alert]).to eq("Flag reason doesn't exist or is not usable for AI flagging")
    end

    it "changes the AI post flag reason without flashing a toggle message if already enabled" do
      another_reason = create(:post_flag_reason, name: "other_ai_reason")
      Setting.automatic_ai_check = true
      Setting.ai_flag_reason = valid_reason.name
      sign_in_as admin
      post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: another_reason.name, automatic_ai_check: "1" } }
      expect(response).to redirect_to(post_flag_reasons_path)
      expect(Setting.ai_flag_reason).to eq(another_reason.name)
      expect(Setting.automatic_ai_check?).to be(true)
      expect(flash[:notice]).to be_nil
    end

    it "is forbidden for a moderator" do
      Setting.automatic_ai_check = false
      sign_in_as moderator
      expect do
        post set_ai_flag_reason_post_flag_reasons_path, params: { ai_flag_reason: { reason: valid_reason.name, automatic_ai_check: "1" } }
      end.not_to change(Setting, :automatic_ai_check)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
