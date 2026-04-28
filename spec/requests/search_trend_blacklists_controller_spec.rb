# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendBlacklistsController do
  let(:admin) { create(:admin_user) }
  let(:standard_user) { create(:member_user) }

  describe "#index" do
    it "renders for admins" do
      sign_in_as admin
      get search_trend_blacklists_path
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      sign_in_as standard_user
      get search_trend_blacklists_path
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects to the login page for anonymous users" do
      get search_trend_blacklists_path
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(new_session_path(url: search_trend_blacklists_path))
      # expect(response.location).to include("/session/new")
    end
  end

  describe "#new" do
    it "renders for admins" do
      sign_in_as admin
      get new_search_trend_blacklist_path
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      sign_in_as standard_user
      get new_search_trend_blacklist_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#create" do
    it "successfully creates a blacklist entry for admins" do
      expect do
        sign_in_as admin
        post search_trend_blacklists_path, params: {
          search_trend_blacklist: { tag: "wolf", reason: "testing" },
        }
      end.to change(SearchTrendBlacklist, :count).by(1)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
      expect(SearchTrendBlacklist.find_by(tag: "wolf")).not_to be_nil
    end

    it "forbids non-admins" do
      expect do
        sign_in_as standard_user
        post search_trend_blacklists_path, params: {
          search_trend_blacklist: { tag: "wolf", reason: "" },
        }
      end.not_to change(SearchTrendBlacklist, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "shows errors for invalid input" do
      expect do
        sign_in_as admin
        post search_trend_blacklists_path, params: {
          search_trend_blacklist: { tag: "", reason: "" },
        }
      end.not_to change(SearchTrendBlacklist, :count)
      expect(response).to have_http_status(:success)
    end
  end

  describe "#edit" do
    let(:entry) do
      CurrentUser.scoped(admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
    end

    it "render for admin" do
      sign_in_as admin
      get edit_search_trend_blacklist_path(entry)
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      sign_in_as standard_user
      get edit_search_trend_blacklist_path(entry)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#update" do
    let(:entry) do
      CurrentUser.scoped(admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "old reason")
      end
    end

    it "update a blacklist entry as admin" do
      sign_in_as admin
      put search_trend_blacklist_path(entry), params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
      expect(entry.reload.reason).to eq("new reason")
    end

    it "forbids non-admins" do
      sign_in_as standard_user
      put search_trend_blacklist_path(entry), params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      expect(response).to have_http_status(:forbidden)
      expect(entry.reload.reason).to eq("old reason")
    end

    it "shows errors for invalid input" do
      bl = CurrentUser.scoped(admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      sign_in_as admin
      put search_trend_blacklist_path(bl), params: {
        search_trend_blacklist: { tag: "" },
      }
      expect(response).to have_http_status(:success)
      expect(bl.reload.tag).to eq("wolf")
    end
  end

  describe "#destroy" do
    let!(:entry) do
      CurrentUser.scoped(admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
    end

    it "delete a blacklist entry as admin" do
      expect do
        sign_in_as admin
        delete search_trend_blacklist_path(entry)
      end.to change(SearchTrendBlacklist, :count).by(-1)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
    end

    it "forbids non-admins" do
      expect do
        sign_in_as standard_user
        delete search_trend_blacklist_path(entry)
      end.not_to change(SearchTrendBlacklist, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
