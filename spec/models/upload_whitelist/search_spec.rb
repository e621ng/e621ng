# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       UploadWhitelist Search                                #
# --------------------------------------------------------------------------- #

RSpec.describe UploadWhitelist do
  before { CurrentUser.user = create(:moderator_user) }
  after  { CurrentUser.user = nil }

  def make_entry(overrides = {})
    create(:upload_whitelist, **overrides)
  end

  describe ".default_order" do
    it "orders entries alphabetically by note" do
      beta  = make_entry(note: "beta entry")
      alpha = make_entry(note: "alpha entry")
      gamma = make_entry(note: "gamma entry")

      ids = UploadWhitelist.default_order.ids
      expect(ids.index(alpha.id)).to be < ids.index(beta.id)
      expect(ids.index(beta.id)).to be  < ids.index(gamma.id)
    end
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # note filter
    # -------------------------------------------------------------------------
    describe "note parameter" do
      let!(:matching)    { make_entry(note: "Trusted image host") }
      let!(:nonmatching) { make_entry(note: "Unrelated entry") }

      it "returns entries whose note matches the pattern (case-insensitive)" do
        results = UploadWhitelist.search(note: "*image*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all entries when note is absent" do
        results = UploadWhitelist.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # order parameter
    # -------------------------------------------------------------------------
    describe "order parameter" do
      let!(:first)  do
        make_entry(domain: "aaa\\.com", path: "\\/aaa", note: "aaa")
      end
      let!(:second) do
        make_entry(domain: "zzz\\.com", path: "\\/zzz", note: "zzz")
      end

      it "orders by domain ascending when order: 'domain'" do
        ids = UploadWhitelist.search(order: "domain").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end

      it "orders by path ascending when order: 'path'" do
        ids = UploadWhitelist.search(order: "path").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end

      it "orders by updated_at descending when order: 'updated_at'" do
        # Touch first so it has a newer updated_at, which should put it first.
        first.touch
        ids = UploadWhitelist.search(order: "updated_at").ids
        expect(ids.index(first.id)).to be < ids.index(second.id)
      end

      it "orders by id descending (newest first) when order: 'created_at'" do
        ids = UploadWhitelist.search(order: "created_at").ids
        expect(ids.index(second.id)).to be < ids.index(first.id)
      end
    end
  end
end
