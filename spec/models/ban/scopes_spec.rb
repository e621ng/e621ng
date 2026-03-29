# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                               Ban Scopes                                    #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  def make_ban(overrides = {})
    create(:ban, user: subject_user, banner: moderator, **overrides)
  end

  describe "scopes" do
    # -------------------------------------------------------------------------
    # .unexpired
    # -------------------------------------------------------------------------
    describe ".unexpired" do
      it "includes bans that expire in the future" do
        ban = make_ban(duration: 30)
        expect(Ban.unexpired).to include(ban)
      end

      it "includes permanent bans (expires_at is NULL)" do
        ban = make_ban(duration: -1)
        expect(Ban.unexpired).to include(ban)
      end

      it "excludes bans that have already expired" do
        ban = make_ban(duration: 30)
        ban.update_column(:expires_at, 1.day.ago)
        expect(Ban.unexpired).not_to include(ban)
      end
    end

    # -------------------------------------------------------------------------
    # .expired
    # -------------------------------------------------------------------------
    describe ".expired" do
      it "includes bans whose expires_at is in the past" do
        ban = make_ban(duration: 30)
        ban.update_column(:expires_at, 1.day.ago)
        expect(Ban.expired).to include(ban)
      end

      it "excludes bans that expire in the future" do
        ban = make_ban(duration: 30)
        expect(Ban.expired).not_to include(ban)
      end

      it "excludes permanent bans (expires_at is NULL)" do
        ban = make_ban(duration: -1)
        expect(Ban.expired).not_to include(ban)
      end
    end
  end
end
