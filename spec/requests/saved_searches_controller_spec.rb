# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearchesController do
  include_context "as member"

  let(:owner) { create(:user) }
  let(:other_member) { create(:user) }

  before { sign_in_as owner }

  describe "GET /saved_searches" do
    it "renders for the owner with fresh counts" do
      create(:saved_search, user: owner, is_tracked: true)
      get saved_searches_path
      expect(response).to have_http_status(:ok)
    end

    it "renders each search as a list item linking to its query" do
      ss = create(:saved_search, user: owner, is_tracked: true, query: Array.new(30) { |i| "long_tag_name_#{i}" }.join(" "))
      get saved_searches_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(id="saved-search-#{ss.id}"))
      expect(response.body).to include(visit_saved_search_path(ss))
      expect(response.body).to include("long_tag_name_29")
      expect(response.body).not_to include("<table")
    end

    it "returns the owner's searches with new_count in JSON" do
      ss = create(:saved_search, user: owner, is_tracked: true)
      create(:saved_search, user: other_member)
      get saved_searches_path(format: :json)
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.pluck("id")).to eq([ss.id])
      expect(body.first).to have_key("new_count")
    end

    context "with a search that can no longer be evaluated" do
      let(:post_set) { create(:public_post_set) }
      let!(:broken) do
        CurrentUser.scoped(owner) { create(:saved_search, user: owner, is_tracked: true, query: "set:#{post_set.shortname}") }
      end

      before { post_set.update_columns(is_public: false) }

      it "still renders, marking the search unavailable" do
        get saved_searches_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(%(id="saved-search-#{broken.id}"))
        expect(response.body).to include("Unavailable")
      end

      it "returns a null new_count in JSON" do
        get saved_searches_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.first).to include("id" => broken.id, "new_count" => nil)
      end
    end

    it "denies anonymous users" do
      sign_in_as nil
      get saved_searches_path
      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "POST /saved_searches" do
    it "creates a saved search" do
      expect do
        post saved_searches_path, params: { saved_search: { query: "fox cat", name: "foxes" } }
      end.to change { owner.saved_searches.count }.by(1)
    end

    it "reports a set the user can't view as a validation error" do
      post_set = create(:post_set)
      post saved_searches_path(format: :json), params: { saved_search: { query: "set:#{post_set.shortname}" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(owner.saved_searches.count).to eq(0)
    end

    it "creates a tracked search with a seeded watermark" do
      create(:post)
      post saved_searches_path, params: { saved_search: { query: "fox", is_tracked: "1" } }
      ss = owner.saved_searches.last
      expect(ss.is_tracked?).to be(true)
      expect(ss.last_seen_post_id).to eq(Post.maximum(:id))
    end

    it "rejects wildcard queries with a clean error over JSON" do
      post saved_searches_path(format: :json), params: { saved_search: { query: "fox_*" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["message"]).to match(/wildcard/)
    end
  end

  describe "PUT /saved_searches/:id" do
    it "updates the owner's search" do
      ss = create(:saved_search, user: owner)
      put saved_search_path(ss), params: { saved_search: { is_tracked: "1" } }
      expect(ss.reload.is_tracked?).to be(true)
    end

    it "404s on another user's search" do
      ss = create(:saved_search, user: other_member)
      put saved_search_path(ss), params: { saved_search: { is_tracked: "1" } }
      expect(response).to have_http_status(:not_found)
      expect(ss.reload.is_tracked?).to be(false)
    end
  end

  describe "DELETE /saved_searches/:id" do
    it "destroys the owner's search" do
      ss = create(:saved_search, user: owner)
      expect do
        delete saved_search_path(ss)
      end.to change { owner.saved_searches.count }.by(-1)
    end

    it "404s on another user's search" do
      ss = create(:saved_search, user: other_member)
      delete saved_search_path(ss)
      expect(response).to have_http_status(:not_found)
      expect(SavedSearch.exists?(ss.id)).to be(true)
    end
  end

  describe "GET /saved_searches/:id/visit" do
    it "advances the watermark and redirects to the only-new view" do
      create(:post)
      ss = create(:saved_search, user: owner, name: "foxes", query: "fox", is_tracked: true)
      old_watermark = ss.last_seen_post_id
      create(:post)
      get visit_saved_search_path(ss)
      expect(response).to redirect_to(posts_path(tags: "search:foxes id:>#{old_watermark}"))
      expect(ss.reload.last_seen_post_id).to eq(Post.maximum(:id))
    end

    it "redirects untracked searches without a watermark filter" do
      ss = create(:saved_search, user: owner, name: "foxes", query: "fox")
      get visit_saved_search_path(ss)
      expect(response).to redirect_to(posts_path(tags: "search:foxes"))
    end

    it "falls back to the id for unnamed searches" do
      ss = create(:saved_search, user: owner, name: nil, query: "fox")
      get visit_saved_search_path(ss)
      expect(response).to redirect_to(posts_path(tags: "search:#{ss.id}"))
    end

    it "zeroes the cached badge entry" do
      ss = create(:saved_search, user: owner, is_tracked: true)
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(owner.id), { ss.id => 7 })
      get visit_saved_search_path(ss)
      expect(SavedSearch.badge_counts(owner)).to eq({ ss.id => 0 })
    end
  end

  describe "POST /saved_searches/mark_all_seen" do
    it "zeroes all tracked searches" do
      ss = create(:saved_search, user: owner, is_tracked: true)
      create(:post)
      post mark_all_seen_saved_searches_path
      expect(response).to redirect_to(saved_searches_path)
      expect(ss.reload.last_seen_post_id).to eq(Post.maximum(:id))
    end
  end

  describe "badge job gating" do
    it "enqueues a badge refresh on page load for flagged users with a cold cache" do
      create(:saved_search, user: owner, is_tracked: true)
      # sign_in_as pins the in-memory object; pick up the flag written by update_all
      owner.reload
      Cache.delete(SavedSearch.badge_cache_key(owner.id))
      expect do
        get posts_path
      end.to enqueue_sidekiq_job(SavedSearchBadgeJob).with(owner.id, false)
    end

    it "does not enqueue for users without tracked searches" do
      expect do
        get posts_path
      end.not_to enqueue_sidekiq_job(SavedSearchBadgeJob)
    end

    it "flags a stale count in the navigation so the page re-reads it" do
      ss = create(:saved_search, user: owner, is_tracked: true)
      owner.reload
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(owner.id), { ss.id => 4 }, at: 1.hour.ago.to_i)
      get posts_path
      expect(response.body).to include('data-notif-count="4"')
      expect(response.body).to include("data-notif-stale")
    end

    it "does not flag a fresh count" do
      ss = create(:saved_search, user: owner, is_tracked: true)
      owner.reload
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(owner.id), { ss.id => 4 })
      get posts_path
      expect(response.body).to include('data-notif-count="4"')
      expect(response.body).not_to include("data-notif-stale")
    end
  end

  describe "GET /saved_searches/badge.json" do
    let!(:saved_search) { create(:saved_search, user: owner, is_tracked: true) }
    let(:cache_key) { SavedSearch.badge_cache_key(owner.id) }

    it "returns a fresh count" do
      SavedSearch.write_badge_entry(cache_key, { saved_search.id => 4 })
      get badge_saved_searches_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ "count" => 4, "fresh" => true })
    end

    it "returns the last known count for a stale entry" do
      SavedSearch.write_badge_entry(cache_key, { saved_search.id => 4 }, at: 1.hour.ago.to_i)
      get badge_saved_searches_path(format: :json)
      expect(response.parsed_body).to eq({ "count" => 4, "fresh" => false })
    end

    it "returns a null count when nothing is cached" do
      Cache.delete(cache_key)
      get badge_saved_searches_path(format: :json)
      expect(response.parsed_body).to eq({ "count" => nil, "fresh" => false })
    end

    it "never enqueues a refresh" do
      Cache.delete(cache_key)
      expect do
        get badge_saved_searches_path(format: :json)
      end.not_to enqueue_sidekiq_job(SavedSearchBadgeJob)
    end

    it "denies anonymous users" do
      sign_in_as nil
      get badge_saved_searches_path(format: :json)
      expect(response).not_to have_http_status(:ok)
    end
  end
end
