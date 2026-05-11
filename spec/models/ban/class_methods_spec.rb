# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Ban Class Methods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "class methods" do
    # -------------------------------------------------------------------------
    # .is_banned?
    # -------------------------------------------------------------------------
    describe ".is_banned?" do
      it "returns true when an unexpired ban exists for the user" do
        create(:ban, user: subject_user, banner: moderator)
        expect(Ban.is_banned?(subject_user)).to be(true)
      end

      it "returns true when a permanent ban exists for the user" do
        create(:permaban, user: subject_user, banner: moderator)
        expect(Ban.is_banned?(subject_user)).to be(true)
      end

      it "returns false when no ban exists for the user" do
        expect(Ban.is_banned?(subject_user)).to be(false)
      end

      it "returns false when the only ban has already expired" do
        ban = create(:ban, user: subject_user, banner: moderator)
        ban.update_column(:expires_at, 1.day.ago)
        expect(Ban.is_banned?(subject_user)).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # .prune!
    # -------------------------------------------------------------------------
    describe ".prune!" do
      it "unbans a user whose ban has expired" do
        ban = create(:ban, user: subject_user, banner: moderator)
        # Set expires_at in the past to simulate an expired ban using update_column
        # so that callbacks (which would reset is_banned) are intentionally skipped.
        ban.update_column(:expires_at, 1.day.ago)
        # subject_user.is_banned was set to true by the after_create callback; reload.
        subject_user.reload

        Ban.prune!

        expect(subject_user.reload.is_banned).to be(false)
        expect(subject_user.reload.level).to eq(User::Levels::MEMBER)
      end

      it "does not unban a user whose ban is still active" do
        create(:ban, user: subject_user, banner: moderator, duration: 30)

        Ban.prune!

        expect(subject_user.reload.is_banned).to be(true)
      end

      it "does not unban a user with a permanent ban" do
        create(:permaban, user: subject_user, banner: moderator)

        Ban.prune!

        expect(subject_user.reload.is_banned).to be(true)
      end
    end
  end
end
