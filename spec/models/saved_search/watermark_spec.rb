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
    it "returns the old watermark and advances to the current max when there was something new" do
      ss = create(:saved_search, user: user, is_tracked: true)
      old_watermark = ss.last_seen_post_id
      newer = create(:post)
      expect(ss.mark_seen!(new_count: 1)).to eq(old_watermark)
      expect(ss.reload.last_seen_post_id).to eq(newer.id)
    end

    it "returns nil but still advances when there was nothing new" do
      ss = create(:saved_search, user: user, is_tracked: true)
      newer = create(:post)
      expect(ss.mark_seen!(new_count: 0)).to be_nil
      expect(ss.reload.last_seen_post_id).to eq(newer.id)
    end

    it "defaults to the cached count for the current safe-mode variant" do
      ss = create(:saved_search, user: user, is_tracked: true)
      old_watermark = ss.last_seen_post_id
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { ss.id => 2 })
      expect(ss.mark_seen!).to eq(old_watermark)
    end

    it "treats an unevaluable (nil) cached count as nothing new" do
      ss = create(:saved_search, user: user, is_tracked: true)
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { ss.id => nil })
      expect(ss.mark_seen!).to be_nil
    end

    it "zeroes only this search's cached badge entry" do
      ss = create(:saved_search, user: user, is_tracked: true)
      other = create(:saved_search, user: user, is_tracked: true)
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { ss.id => 5, other.id => 3 })
      ss.mark_seen!
      expect(SavedSearch.badge_counts(user)).to eq({ ss.id => 0, other.id => 3 })
    end

    it "keeps the entry's timestamp so visits don't postpone the refresh" do
      ss = create(:saved_search, user: user, is_tracked: true)
      stamp = 10.minutes.ago.to_i
      SavedSearch.write_badge_entry(SavedSearch.badge_cache_key(user.id), { ss.id => 5 }, at: stamp)
      ss.mark_seen!
      expect(SavedSearch.badge_entry(user)).to eq({ counts: { ss.id => 0 }, at: stamp })
    end

    it "zeroes the entry in both safe-mode variants" do
      ss = create(:saved_search, user: user, is_tracked: true)
      SavedSearch.badge_cache_keys(user.id).each { |key| SavedSearch.write_badge_entry(key, { ss.id => 5 }) }
      ss.mark_seen!
      expect(SavedSearch.badge_counts(user, safe_mode: false)).to eq({ ss.id => 0 })
      expect(SavedSearch.badge_counts(user, safe_mode: true)).to eq({ ss.id => 0 })
    end

    it "is a no-op for untracked searches" do
      ss = create(:saved_search, user: user)
      expect(ss.mark_seen!(new_count: 5)).to be_nil
      expect(ss.reload.last_seen_post_id).to be_nil
    end
  end

  describe "#visit_tags" do
    it "appends the old watermark only when there was something new" do
      ss = create(:saved_search, user: user, name: "foxes", is_tracked: true)
      old_watermark = ss.last_seen_post_id
      expect(ss.visit_tags(new_count: 3)).to eq("search:foxes id:>#{old_watermark}")
      expect(ss.visit_tags(new_count: 0)).to eq("search:foxes")
    end

    it "falls back to the id for unnamed searches" do
      ss = create(:saved_search, user: user, name: nil)
      expect(ss.visit_tags(new_count: 3)).to eq("search:#{ss.id}")
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
      expect(SavedSearch.badge_counts(user, safe_mode: false)).to eq({ ss1.id => 0, ss2.id => 0 })
      expect(SavedSearch.badge_counts(user, safe_mode: true)).to eq({ ss1.id => 0, ss2.id => 0 })
    end
  end

  describe "per-site watermarks" do
    include_context "with e926 site profile"

    def as_e926(&)
      CurrentSite.with("e926", &)
    end

    def counts_per_key(saved_search)
      SavedSearch.badge_cache_keys(user.id).index_with { |key| SavedSearch.read_badge_entry(key)[:counts][saved_search.id] }
    end

    it "seeds only the primary watermark when created tracked on a profile" do
      ss = as_e926 { create(:saved_search, user: user, is_tracked: true) }
      expect(ss).to have_attributes(last_seen_post_id: Post.maximum(:id), site_watermarks: {})
    end

    it "#watermark falls back to the primary's on a profile without its own" do
      ss = create(:saved_search, user: user, is_tracked: true)
      expect(as_e926 { ss.watermark }).to eq(ss.last_seen_post_id)
    end

    it "#watermark is the newer of the primary's and the profile's" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.update_column(:site_watermarks, { "e926" => ss.last_seen_post_id + 10 })
      expect(as_e926 { ss.watermark }).to eq(ss.last_seen_post_id + 10)
      expect(ss.watermark).to eq(ss.last_seen_post_id)
      ss.update_column(:site_watermarks, { "e926" => ss.last_seen_post_id - 1 })
      expect(as_e926 { ss.watermark }).to eq(ss.last_seen_post_id)
    end

    it "clears the profile keys on re-track" do
      ss = create(:saved_search, user: user, is_tracked: true)
      ss.update_column(:site_watermarks, { "e926" => 1 })
      ss.update!(is_tracked: false)
      expect(ss.reload.site_watermarks).to eq({})
    end

    describe "#mark_seen! on a profile" do
      it "records only that site's watermark and returns the old effective one" do
        ss = create(:saved_search, user: user, is_tracked: true)
        primary = ss.last_seen_post_id
        newer = create(:post)
        expect(as_e926 { ss.mark_seen!(new_count: 1) }).to eq(primary)
        expect(ss.site_watermarks).to eq({ "e926" => newer.id })
        expect(ss.reload).to have_attributes(last_seen_post_id: primary, site_watermarks: { "e926" => newer.id })
      end

      it "merges with other profiles' keys" do
        ss = create(:saved_search, user: user, is_tracked: true)
        ss.update_column(:site_watermarks, { "pony" => 5 })
        newer = create(:post)
        as_e926 { ss.mark_seen! }
        expect(ss.reload.site_watermarks).to eq({ "pony" => 5, "e926" => newer.id })
      end

      it "zeroes only that site's cached entries" do
        ss = create(:saved_search, user: user, is_tracked: true)
        SavedSearch.badge_cache_keys(user.id).each { |key| SavedSearch.write_badge_entry(key, { ss.id => 5 }) }
        as_e926 { ss.mark_seen! }
        expect(counts_per_key(ss)).to eq(
          "ssb:#{user.id}" => 5,
          "ssb:#{user.id}:s" => 5,
          "ssb:#{user.id}:e926" => 0,
          "ssb:#{user.id}:e926:s" => 0,
        )
      end

      it "lands #visit_tags on the profile's watermark" do
        ss = create(:saved_search, user: user, name: "foxes", is_tracked: true)
        ss.update_column(:site_watermarks, { "e926" => ss.last_seen_post_id + 10 })
        expect(as_e926 { ss.visit_tags(new_count: 1) }).to eq("search:foxes id:>#{ss.last_seen_post_id + 10}")
      end
    end

    describe "#mark_seen! on the primary site" do
      it "resets the profile watermarks and zeroes every site's entries" do
        ss = create(:saved_search, user: user, is_tracked: true)
        ss.update_column(:site_watermarks, { "e926" => ss.last_seen_post_id })
        SavedSearch.badge_cache_keys(user.id).each { |key| SavedSearch.write_badge_entry(key, { ss.id => 5 }) }
        newer = create(:post)
        ss.mark_seen!
        expect(ss.reload).to have_attributes(last_seen_post_id: newer.id, site_watermarks: {})
        expect(counts_per_key(ss).values).to all(eq(0))
      end
    end

    describe ".mark_all_seen!" do
      it "on a profile merges the site key into every tracked search" do
        ss1 = create(:saved_search, user: user, is_tracked: true)
        ss2 = create(:saved_search, user: user, is_tracked: true)
        ss2.update_column(:site_watermarks, { "pony" => 5 })
        primary = ss1.last_seen_post_id
        newer = create(:post)
        as_e926 { SavedSearch.mark_all_seen!(user) }
        expect(ss1.reload).to have_attributes(last_seen_post_id: primary, site_watermarks: { "e926" => newer.id })
        expect(ss2.reload.site_watermarks).to eq({ "pony" => 5, "e926" => newer.id })
        expect(as_e926 { SavedSearch.badge_counts(user) }).to eq({ ss1.id => 0, ss2.id => 0 })
        expect(SavedSearch.badge_counts(user)).to be_nil
      end

      it "on the primary site clears the profile keys" do
        ss = create(:saved_search, user: user, is_tracked: true)
        ss.update_column(:site_watermarks, { "e926" => ss.last_seen_post_id })
        newer = create(:post)
        SavedSearch.mark_all_seen!(user)
        expect(ss.reload).to have_attributes(last_seen_post_id: newer.id, site_watermarks: {})
        expect(as_e926 { SavedSearch.badge_counts(user) }).to eq({ ss.id => 0 })
      end
    end

    # Unique tag names: the test index keeps documents from earlier examples in the run
    it "keeps the primary backlog when a profile visit is marked seen" do
      tag = "watermark_#{SecureRandom.hex(4)}"
      create(:post, tag_string: tag, rating: "s")
      ss = create(:saved_search, user: user, query: tag, is_tracked: true)
      2.times { create(:post, tag_string: tag, rating: "s") }
      2.times { create(:post, tag_string: tag, rating: "e") }

      expect(SavedSearch.refresh_badge_counts!(user, safe_mode: false)).to eq({ ss.id => 4 })
      as_e926 do
        expect(SavedSearch.refresh_badge_counts!(user)).to eq({ ss.id => 2 })
        ss.mark_seen!
        expect(SavedSearch.badge_counts(user)).to eq({ ss.id => 0 })
        expect(SavedSearch.new_post_count(ss)).to eq(0)
      end
      expect(SavedSearch.badge_counts(user, safe_mode: false)).to eq({ ss.id => 4 })
      expect(SavedSearch.new_post_count(ss, safe_mode: false)).to eq(4)

      ss.mark_seen!
      expect(ss.reload.site_watermarks).to eq({})
      expect(SavedSearch.badge_counts(user, safe_mode: false)).to eq({ ss.id => 0 })
      expect(SavedSearch.new_post_count(ss, safe_mode: false)).to eq(0)
      expect(as_e926 { SavedSearch.new_post_count(ss) }).to eq(0)
    end

    it "needs no profile write when the primary visit comes first" do
      tag = "watermark_#{SecureRandom.hex(4)}"
      create(:post, tag_string: tag, rating: "s")
      ss = create(:saved_search, user: user, query: tag, is_tracked: true)
      create(:post, tag_string: tag, rating: "s")
      create(:post, tag_string: tag, rating: "e")
      ss.mark_seen!
      expect(ss.reload.site_watermarks).to eq({})
      expect(as_e926 { SavedSearch.new_post_count(ss) }).to eq(0)
    end
  end
end
