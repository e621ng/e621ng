# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                               Ban.search                                    #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  def make_ban(overrides = {})
    create(:ban, user: subject_user, banner: moderator, **overrides)
  end

  describe ".search" do
    # -------------------------------------------------------------------------
    # banner filter
    # -------------------------------------------------------------------------
    describe "banner filter" do
      let(:other_banner) { create(:moderator_user) }
      let!(:own_ban)   { make_ban }
      let!(:other_ban) { create(:ban, user: create(:user), banner: other_banner) }

      it "filters by banner_name" do
        # where_user builds string keys ("banner_name") for name-based lookups.
        results = Ban.search(banner_name: moderator.name)
        expect(results).to include(own_ban)
        expect(results).not_to include(other_ban)
      end
    end

    # -------------------------------------------------------------------------
    # user filter (subject of the ban)
    # -------------------------------------------------------------------------
    describe "user filter" do
      let(:other_user) { create(:user) }
      let!(:own_ban)   { make_ban }
      let!(:other_ban) { create(:ban, user: other_user, banner: moderator) }

      it "filters by user_name" do
        results = Ban.search(user_name: subject_user.name)
        expect(results).to include(own_ban)
        expect(results).not_to include(other_ban)
      end
    end

    # -------------------------------------------------------------------------
    # reason_matches
    # -------------------------------------------------------------------------
    describe "reason_matches" do
      let!(:matching)    { make_ban(reason: "spamming the forums") }
      let!(:nonmatching) { make_ban(reason: "art theft") }

      it "returns bans whose reason matches the wildcard pattern" do
        results = Ban.search(reason_matches: "*spamming*")
        expect(results).to include(matching)
        expect(results).not_to include(nonmatching)
      end

      it "returns all bans when reason_matches is absent" do
        results = Ban.search({})
        expect(results).to include(matching, nonmatching)
      end
    end

    # -------------------------------------------------------------------------
    # expired filter
    # -------------------------------------------------------------------------
    describe "expired filter" do
      let!(:active_ban)  { make_ban(duration: 30) }
      let!(:expired_ban) do
        b = make_ban(duration: 30)
        b.update_column(:expires_at, 1.day.ago)
        b
      end

      it "returns only expired bans when expired is truthy" do
        results = Ban.search(expired: "1")
        expect(results).to include(expired_ban)
        expect(results).not_to include(active_ban)
      end

      it "returns only unexpired bans when expired is falsy" do
        results = Ban.search(expired: "0")
        expect(results).to include(active_ban)
        expect(results).not_to include(expired_ban)
      end

      it "returns all bans when expired is absent" do
        results = Ban.search({})
        expect(results).to include(active_ban, expired_ban)
      end
    end

    # -------------------------------------------------------------------------
    # order
    # -------------------------------------------------------------------------
    describe "order" do
      it "orders by expires_at descending when order is 'expires_at_desc'" do
        sooner = make_ban(duration: 7)
        later  = make_ban(duration: 365)
        results = Ban.search(order: "expires_at_desc").to_a
        expect(results.index(later)).to be < results.index(sooner)
      end

      it "applies default ordering when order is not specified" do
        expect { Ban.search({}).to_a }.not_to raise_error
      end
    end
  end
end
