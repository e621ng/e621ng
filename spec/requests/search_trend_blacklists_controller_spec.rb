# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchTrendBlacklistsController do
  let(:admin) { create(:admin_user) }
  let(:standard_user) { create(:member_user) }

  describe "#index" do
    it "renders for admins" do
      get_auth search_trend_blacklists_path, admin
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      get_auth search_trend_blacklists_path, standard_user
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
      get_auth new_search_trend_blacklist_path, admin
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      get_auth new_search_trend_blacklist_path, standard_user
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "#create" do
    it "successfully creates a blacklist entry for admins" do
      expect do
        post_auth search_trend_blacklists_path, admin, params: {
          search_trend_blacklist: { tag: "wolf", reason: "testing" },
        }
      end.to change(SearchTrendBlacklist, :count).by(1)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
      expect(SearchTrendBlacklist.find_by(tag: "wolf")).not_to be_nil
    end

    it "forbids non-admins" do
      expect do
        post_auth search_trend_blacklists_path, standard_user, params: {
          search_trend_blacklist: { tag: "wolf", reason: "" },
        }
      end.not_to change(SearchTrendBlacklist, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "shows errors for invalid input" do
      expect do
        post_auth search_trend_blacklists_path, admin, params: {
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
      get_auth edit_search_trend_blacklist_path(entry), admin
      expect(response).to have_http_status(:success)
    end

    it "forbids non-admins" do
      get_auth edit_search_trend_blacklist_path(entry), standard_user
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
      put_auth search_trend_blacklist_path(entry), admin, params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
      expect(entry.reload.reason).to eq("new reason")
    end

    it "forbids non-admins" do
      put_auth search_trend_blacklist_path(entry), standard_user, params: {
        search_trend_blacklist: { tag: "wolf", reason: "new reason" },
      }
      expect(response).to have_http_status(:forbidden)
      expect(entry.reload.reason).to eq("old reason")
    end

    it "shows errors for invalid input" do
      bl = CurrentUser.scoped(admin) do
        SearchTrendBlacklist.create!(tag: "wolf", reason: "")
      end
      put_auth search_trend_blacklist_path(bl), admin, params: {
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
        delete_auth search_trend_blacklist_path(entry), admin
      end.to change(SearchTrendBlacklist, :count).by(-1)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(search_trend_blacklists_path)
    end

    it "forbids non-admins" do
      expect do
        delete_auth search_trend_blacklist_path(entry), standard_user
      end.not_to change(SearchTrendBlacklist, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
