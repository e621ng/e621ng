# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostApprovalsController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:admin)  { create(:admin_user) }

  # ---------------------------------------------------------------------------
  # GET /post_approvals — index
  # ---------------------------------------------------------------------------

  describe "GET /post_approvals" do
    it "returns 200 for anonymous" do
      get post_approvals_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get post_approvals_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get post_approvals_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get post_approvals_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "orders results newest first by default" do
      older = create(:post_approval)
      newer = create(:post_approval)
      older.update_columns(created_at: 2.days.ago)
      newer.update_columns(created_at: 1.day.ago)
      get post_approvals_path(format: :json)
      ids = response.parsed_body.pluck("id")
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end

    it "filters by post_id" do
      matching = create(:post_approval)
      other    = create(:post_approval)
      get post_approvals_path(format: :json, search: { post_id: matching.post_id })
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(matching.id)
      expect(ids).not_to include(other.id)
    end

    it "filters by user name" do
      approver = create(:user)
      matching = create(:post_approval, user: approver)
      other    = create(:post_approval)
      get post_approvals_path(format: :json, search: { user_name: approver.name })
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(matching.id)
      expect(ids).not_to include(other.id)
    end

    it "limits the number of results" do
      create_list(:post_approval, 3)
      get post_approvals_path(format: :json, limit: 2)
      expect(response.parsed_body.length).to eq(2)
    end
  end
end
