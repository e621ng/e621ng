# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearch do
  include_context "as member"

  let(:user) { CurrentUser.user }

  describe "has_tracked_saved_searches flag sync" do
    it "sets the flag when a tracked search is created" do
      expect(user.has_tracked_saved_searches).to be(false)
      create(:saved_search, user: user, is_tracked: true)
      expect(user.reload.has_tracked_saved_searches).to be(true)
    end

    it "does not set the flag for untracked searches" do
      create(:saved_search, user: user)
      expect(user.reload.has_tracked_saved_searches).to be(false)
    end

    it "sets the flag when tracking is enabled on an existing search" do
      ss = create(:saved_search, user: user)
      ss.update!(is_tracked: true)
      expect(user.reload.has_tracked_saved_searches).to be(true)
    end

    it "clears the flag when the last tracked search is untracked" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.update!(is_tracked: false)
      expect(user.reload.has_tracked_saved_searches).to be(false)
    end

    it "clears the flag when the last tracked search is destroyed" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.destroy!
      expect(user.reload.has_tracked_saved_searches).to be(false)
    end

    it "keeps the flag while another tracked search remains" do
      create(:saved_search, user: user, is_tracked: true)
      second = create(:saved_search, user: user, is_tracked: true)
      second.destroy!
      expect(user.reload.has_tracked_saved_searches).to be(true)
    end

    it "does not clobber other bit prefs" do
      user.update_columns(bit_prefs: user.bit_prefs | User.flag_value_for("enable_safe_mode"))
      create(:saved_search, user: user, is_tracked: true)
      expect(user.reload.enable_safe_mode).to be(true)
    end

    it "drops the cached badge map on any tracking change" do
      ss = create(:saved_search, user: user, is_tracked: true)
      SavedSearch.badge_cache_keys(user.id).each { |key| SavedSearch.write_badge_entry(key, { ss.id => 5 }) }
      ss.update!(is_tracked: false)
      expect(SavedSearch.badge_counts(user, safe_mode: false)).to be_nil
      expect(SavedSearch.badge_counts(user, safe_mode: true)).to be_nil
    end
  end
end
