# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              Ban Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:admin)        { create(:admin_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "validations" do
    # -------------------------------------------------------------------------
    # user_id
    # -------------------------------------------------------------------------
    describe "user_id" do
      it "is invalid without a user" do
        ban = build(:ban, user: nil, banner: moderator)
        expect(ban).not_to be_valid
        expect(ban.errors[:user_id]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # reason
    # -------------------------------------------------------------------------
    describe "reason" do
      it "is invalid without a reason" do
        ban = build(:ban, user: subject_user, banner: moderator, reason: nil)
        expect(ban).not_to be_valid
        expect(ban.errors[:reason]).to be_present
      end

      it "is invalid with a blank reason" do
        ban = build(:ban, user: subject_user, banner: moderator, reason: "")
        expect(ban).not_to be_valid
        expect(ban.errors[:reason]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # duration
    # -------------------------------------------------------------------------
    describe "duration" do
      it "is invalid when duration is not set" do
        ban = Ban.new(user: subject_user, banner: moderator, reason: "reason")
        expect(ban).not_to be_valid
        expect(ban.errors[:duration]).to be_present
      end

      it "is invalid when duration is 0 (does not populate @duration)" do
        ban = Ban.new(user: subject_user, banner: moderator, reason: "reason")
        ban.duration = 0
        expect(ban).not_to be_valid
        expect(ban.errors[:duration]).to be_present
      end

      it "is valid with a positive duration" do
        ban = build(:ban, user: subject_user, banner: moderator, duration: 7)
        expect(ban).to be_valid
      end

      it "is valid with a negative duration (permanent ban)" do
        ban = build(:ban, user: subject_user, banner: moderator, duration: -1)
        expect(ban).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # user_is_inferior (role hierarchy enforcement)
    # -------------------------------------------------------------------------
    describe "user_is_inferior" do
      it "is invalid when trying to ban an admin" do
        ban = build(:ban, user: admin, banner: moderator)
        expect(ban).not_to be_valid
        expect(ban.errors[:base]).to include("You can never ban an admin.")
      end

      it "is invalid when a moderator tries to ban another moderator" do
        other_mod = create(:moderator_user)
        ban = build(:ban, user: other_mod, banner: moderator)
        expect(ban).not_to be_valid
        expect(ban.errors[:base]).to include("Only admins can ban moderators.")
      end

      it "is valid when an admin bans a moderator" do
        CurrentUser.user = admin
        other_mod = create(:moderator_user)
        ban = build(:ban, user: other_mod, banner: admin)
        expect(ban).to be_valid
      end

      it "is valid when a moderator bans a regular member" do
        ban = build(:ban, user: subject_user, banner: moderator)
        expect(ban).to be_valid
      end

      it "is valid when an admin bans a regular member" do
        CurrentUser.user = admin
        ban = build(:ban, user: subject_user, banner: admin)
        expect(ban).to be_valid
      end

      it "is invalid when a regular member tries to ban another user" do
        member  = create(:user)
        another = create(:user)
        ban = build(:ban, user: another, banner: member)
        expect(ban).not_to be_valid
        expect(ban.errors[:base]).to include("No one else can ban.")
      end
    end
  end
end
