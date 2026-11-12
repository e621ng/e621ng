# frozen_string_literal: true

require "rails_helper"

# Cached values that depend on the site get a per-site key (doc 38).
RSpec.describe "Per-site cache keys" do # rubocop:disable RSpec/DescribeClass
  include_context "with e926 site profile"

  it "keys the mascot list per site" do
    expect(Mascot.active_cache_key).to eq("active_mascots")
    CurrentSite.with("e926") { expect(Mascot.active_cache_key).to eq("active_mascots:e926") }
  end

  it "keys the ToS per site" do
    expect(ApplicationHelper.tos_cache_key).to eq("tos_content")
    CurrentSite.with("e926") { expect(ApplicationHelper.tos_cache_key).to eq("tos_content:e926") }
  end

  it "clears every site's ToS" do
    Cache.write("tos_content", "a")
    Cache.write("tos_content:e926", "b")
    ApplicationHelper.clear_tos_cache
    expect(Cache.fetch("tos_content")).to be_nil
    expect(Cache.fetch("tos_content:e926")).to be_nil
  end

  it "clears every site's mascot list" do
    mascot = CurrentUser.scoped(create(:admin_user)) { create(:app_mascot) }
    Cache.write("active_mascots", "a")
    Cache.write("active_mascots:e926", "b")
    mascot.invalidate_cache
    expect(Cache.fetch("active_mascots")).to be_nil
    expect(Cache.fetch("active_mascots:e926")).to be_nil
  end

  it "keys the saved-search badge per site and safe-mode variant" do
    expect(SavedSearch.badge_cache_key(1, false)).to eq("ssb:1")
    expect(SavedSearch.badge_cache_key(1, true)).to eq("ssb:1:s")
    CurrentSite.with("e926") { expect(SavedSearch.badge_cache_key(1)).to eq("ssb:1:e926:s") }
    expect(SavedSearch.badge_cache_keys(1)).to contain_exactly("ssb:1", "ssb:1:s", "ssb:1:e926", "ssb:1:e926:s")
  end

  it "clears every site's badge entries on a tracking change" do
    user = create(:user)
    ss = CurrentUser.scoped(user) { create(:saved_search, user: user, is_tracked: true) }
    SavedSearch.badge_cache_keys(user.id).each { |key| SavedSearch.write_badge_entry(key, { ss.id => 1 }) }
    ss.update!(is_tracked: false)
    expect(SavedSearch.badge_cache_keys(user.id).map { |key| Cache.fetch(key) }).to all(be_nil)
  end
end
