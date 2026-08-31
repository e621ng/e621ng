# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedSearch do
  include_context "as member"

  let(:user) { CurrentUser.user }

  before { create(:post) }

  describe "watermark seeding" do
    it "stays nil for untracked searches" do
      expect(create(:saved_search, user: user).last_seen_post_id).to be_nil
    end

    it "seeds to the current max post id when created tracked" do
      ss = create(:saved_search, user: user, is_tracked: true)
      expect(ss.last_seen_post_id).to eq(Post.maximum(:id))
    end

    it "nulls the watermark when tracking is turned off" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.update!(is_tracked: false)
      expect(ss.last_seen_post_id).to be_nil
    end

    it "re-seeds on re-track so no backlog accumulates" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.update!(is_tracked: false)
      newer = create(:post)
      ss.update!(is_tracked: true)
      expect(ss.last_seen_post_id).to eq(newer.id)
    end
  end

  describe "#mark_seen!" do
    it "returns the old watermark and advances to the current max" do
      ss = create(:saved_search, user: user, is_tracked: true)
      old_watermark = ss.last_seen_post_id
      newer = create(:post)
      expect(ss.mark_seen!).to eq(old_watermark)
      expect(ss.reload.last_seen_post_id).to eq(newer.id)
    end

    it "zeroes only this search's cached badge entry" do
      ss = create(:saved_search, user: user, is_tracked: true)
      other = create(:saved_search, user: user, is_tracked: true)
      Cache.write(SavedSearch.badge_cache_key(user.id), { ss.id => 5, other.id => 3 })
      ss.mark_seen!
      expect(SavedSearch.badge_counts(user)).to eq({ ss.id => 0, other.id => 3 })
    end

    it "is a no-op for untracked searches" do
      ss = create(:saved_search, user: user)
      expect(ss.mark_seen!).to be_nil
      expect(ss.reload.last_seen_post_id).to be_nil
    end
  end

  describe ".mark_all_seen!" do
    it "advances all tracked watermarks and writes an all-zeros map" do
      ss1 = create(:saved_search, user: user, is_tracked: true)
      ss2 = create(:saved_search, user: user, is_tracked: true)
      newer = create(:post)
      SavedSearch.mark_all_seen!(user)
      expect(ss1.reload.last_seen_post_id).to eq(newer.id)
      expect(ss2.reload.last_seen_post_id).to eq(newer.id)
      expect(SavedSearch.badge_counts(user)).to eq({ ss1.id => 0, ss2.id => 0 })
    end
  end
end
