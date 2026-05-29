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
end
