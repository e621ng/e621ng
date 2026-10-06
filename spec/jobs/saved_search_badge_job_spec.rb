# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearchBadgeJob do
  include_context "as member"

  let(:user) { CurrentUser.user }

  def run_job
    described_class.new.perform(user.id)
  end

  it "does nothing for users without the tracked-searches flag" do
    create(:saved_search, user: user)
    allow(SavedSearch).to receive(:refresh_badge_counts!)
    run_job
    expect(SavedSearch).not_to have_received(:refresh_badge_counts!)
  end

  describe "count computation" do
    it "counts only posts newer than the watermark" do
      create(:post, tag_string: "badge_target old_stuff")
      ss = create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      newer = create(:post, tag_string: "badge_target new_stuff")
      run_job
      counts = SavedSearch.badge_counts(user)
      expect(counts[ss.id]).to eq(1)
      expect(ss.reload.last_seen_post_id).to be < newer.id
    end

    it "reports zero when nothing new matches" do
      create(:post, tag_string: "badge_target")
      ss = create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      run_job
      expect(SavedSearch.badge_counts(user)[ss.id]).to eq(0)
    end

    it "excludes untracked searches from the map" do
      tracked = create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      untracked = create(:saved_search, user: user, query: "other_tag")
      run_job
      counts = SavedSearch.badge_counts(user)
      expect(counts).to have_key(tracked.id)
      expect(counts).not_to have_key(untracked.id)
    end

    it "fails closed to nil for a poisoned stored query" do
      ss = create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      ss.update_column(:query, "wildcard_*")
      run_job
      expect(SavedSearch.badge_counts(user)).to include(ss.id => nil)
    end

    it "reports nil for a set that went private, without failing the other searches" do
      create(:post, tag_string: "badge_target")
      post_set = create(:public_post_set)
      broken = create(:saved_search, user: user, query: "set:#{post_set.shortname}", is_tracked: true)
      healthy = create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      post_set.update_columns(is_public: false)
      create(:post, tag_string: "badge_target")
      run_job
      expect(SavedSearch.badge_counts(user)).to include(broken.id => nil, healthy.id => 1)
    end

    it "reports nil for a user who hid their favorites" do
      other = create(:user)
      ss = create(:saved_search, user: user, query: "fav:#{other.name}", is_tracked: true)
      other.update!(enable_privacy_mode: true)
      run_job
      expect(SavedSearch.badge_counts(user)).to include(ss.id => nil)
    end

    it "reports nil when OpenSearch rejects the query" do
      create(:post)
      ss = create(:saved_search, user: user, query: "age:<99999999999999y", is_tracked: true)
      run_job
      expect(SavedSearch.badge_counts(user)).to include(ss.id => nil)
    end

    it "writes the cache with the configured TTL" do
      create(:saved_search, user: user, query: "badge_target", is_tracked: true)
      allow(Danbooru.config.custom_configuration).to receive(:saved_search_badge_ttl).and_return(3.minutes)
      allow(Cache).to receive(:write).and_call_original
      run_job
      expect(Cache).to have_received(:write).with(SavedSearch.badge_cache_key(user.id), anything, expires_in: 3.minutes)
    end

    it "evaluates as the owning user" do
      ss = create(:saved_search, user: user, query: "fav:me", is_tracked: true)
      run_job
      expect(SavedSearch.badge_counts(user)).to have_key(ss.id)
    end
  end

  describe "request-path gate" do
    it "returns the cached sum for flagged users" do
      ss = create(:saved_search, user: user, is_tracked: true)
      Cache.write(SavedSearch.badge_cache_key(user.id), { ss.id => 4 })
      expect(user.reload.saved_search_new_count).to eq(4)
    end

    it "skips unevaluable searches in the sum" do
      ss = create(:saved_search, user: user, is_tracked: true)
      broken = create(:saved_search, user: user, is_tracked: true)
      Cache.write(SavedSearch.badge_cache_key(user.id), { ss.id => 4, broken.id => nil })
      expect(user.reload.saved_search_new_count).to eq(4)
    end

    it "enqueues a refresh and returns nil on cache miss" do
      create(:saved_search, user: user, is_tracked: true)
      Cache.delete(SavedSearch.badge_cache_key(user.id))
      user.reload
      expect do
        expect(user.saved_search_new_count).to be_nil
      end.to enqueue_sidekiq_job(described_class).with(user.id)
    end

    it "returns nil without touching cache or jobs for unflagged users" do
      allow(Cache).to receive(:fetch)
      expect do
        expect(user.saved_search_new_count).to be_nil
      end.not_to enqueue_sidekiq_job(described_class)
      expect(Cache).not_to have_received(:fetch)
    end
  end
end
