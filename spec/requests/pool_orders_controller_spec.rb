# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolOrdersController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member) { create(:user) }
  let(:pool)   { create(:pool) }

  # ---------------------------------------------------------------------------
  # GET /pools/:pool_id/order/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /pools/:pool_id/order/edit" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        get edit_pool_order_path(pool)
        expect(response).to redirect_to(new_session_path(url: edit_pool_order_path(pool)))
      end

      it "returns 403 for JSON" do
        get edit_pool_order_path(pool, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "returns 200 for HTML" do
        get edit_pool_order_path(pool)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for JSON" do
        get edit_pool_order_path(pool, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for a nonexistent pool" do
        get edit_pool_order_path(pool_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
