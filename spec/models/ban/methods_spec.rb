# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Ban Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  subject(:ban) { create(:ban, user: subject_user, banner: moderator, duration: 30) }

  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "methods" do
    # -------------------------------------------------------------------------
    # #duration= / #duration
    # -------------------------------------------------------------------------
    describe "#duration= and #duration" do
      it "stores a positive duration and sets expires_at to that many days from now" do
        b = Ban.new
        b.duration = 14
        expect(b.duration).to eq(14)
        expect(b.expires_at).to be_within(1.second).of(14.days.from_now)
      end

      it "stores a negative duration and sets expires_at to nil (permanent)" do
        b = Ban.new
        b.duration = -1
        expect(b.duration).to eq(-1)
        expect(b.expires_at).to be_nil
      end

      it "does not set @duration when the value is 0" do
        b = Ban.new
        b.duration = 0
        expect(b.duration).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # #expired?
    # -------------------------------------------------------------------------
    describe "#expired?" do
      it "returns false when expires_at is nil (permanent ban)" do
        expect(create(:permaban, user: subject_user, banner: moderator).expired?).to be(false)
      end

      it "returns false when expires_at is in the future" do
        expect(ban.expired?).to be(false)
      end

      it "returns true when expires_at is in the past" do
        ban.update_column(:expires_at, 1.day.ago)
        expect(ban.expired?).to be(true)
      end
    end

    # -------------------------------------------------------------------------
    # #humanized_duration
    # -------------------------------------------------------------------------
    describe "#humanized_duration" do
      it "returns 'permanent' for a permanent ban" do
        b = create(:permaban, user: subject_user, banner: moderator)
        expect(b.humanized_duration).to eq("permanent")
      end

      it "returns a non-empty string for a timed ban" do
        expect(ban.humanized_duration).to be_a(String).and be_present
      end
    end

    # -------------------------------------------------------------------------
    # #humanized_expiration
    # -------------------------------------------------------------------------
    describe "#humanized_expiration" do
      it "returns 'never' for a permanent ban" do
        b = create(:permaban, user: subject_user, banner: moderator)
        expect(b.humanized_expiration).to eq("never")
      end

      it "returns a non-empty string for a timed ban" do
        expect(ban.humanized_expiration).to be_a(String).and be_present
      end
    end

    # -------------------------------------------------------------------------
    # #expire_days
    # -------------------------------------------------------------------------
    describe "#expire_days" do
      it "returns 'never' for a permanent ban" do
        b = create(:permaban, user: subject_user, banner: moderator)
        expect(b.expire_days).to eq("never")
      end

      it "returns a non-empty string for a timed ban" do
        expect(ban.expire_days).to be_a(String).and be_present
      end
    end

    # -------------------------------------------------------------------------
    # #user_name / #user_name=
    # -------------------------------------------------------------------------
    describe "#user_name" do
      it "returns the name of the banned user" do
        expect(ban.user_name).to eq(subject_user.name)
      end
    end

    describe "#user_name=" do
      it "assigns user_id by looking up the name" do
        other = create(:user)
        ban.user_name = other.name
        expect(ban.user_id).to eq(other.id)
      end

      it "sets user_id to nil when the name does not exist" do
        ban.user_name = "no_such_user_xyz_123"
        expect(ban.user_id).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # #is_permaban= (initialize_permaban via before_validation)
    # -------------------------------------------------------------------------
    describe "#is_permaban / initialize_permaban" do
      it "sets duration to -1 and clears expires_at when is_permaban is '1'" do
        b = build(:ban, user: subject_user, banner: moderator, is_permaban: "1")
        b.valid?
        expect(b.expires_at).to be_nil
        expect(b.duration).to eq(-1)
      end

      it "does not change duration when is_permaban is not '1'" do
        b = build(:ban, user: subject_user, banner: moderator, duration: 7, is_permaban: "0")
        b.valid?
        expect(b.expires_at).to be_present
      end
    end
  end
end
