# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Artist Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  describe "validations" do
    # -------------------------------------------------------------------------
    # name — length
    # -------------------------------------------------------------------------
    describe "name length" do
      it "is invalid when name exceeds 100 characters" do
        artist = build(:artist, name: "a" * 101)
        expect(artist).not_to be_valid
        expect(artist.errors[:name]).to be_present
      end

      it "is valid at exactly 100 characters" do
        expect(build(:artist, name: "a" * 100)).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # name — uniqueness (only checked when name_changed?)
    # -------------------------------------------------------------------------
    describe "name uniqueness" do
      it "is invalid when an artist with the same name already exists" do
        create(:artist, name: "duplicate_artist")
        duplicate = build(:artist, name: "duplicate_artist")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to be_present
      end

      it "does not re-enforce uniqueness on update when name is unchanged" do
        artist = create(:artist)
        artist.group_name = "some_group"
        expect(artist).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # name — tag_name format (only when name_changed?)
    # -------------------------------------------------------------------------
    describe "name format" do
      it "is invalid for a name starting with a dash" do
        artist = build(:artist, name: "-bad_name")
        expect(artist).not_to be_valid
        expect(artist.errors[:name]).to be_present
      end

      it "does not re-validate name format on update when name is unchanged" do
        artist = create(:artist)
        artist.update_columns(name: "-corrupt_name")
        artist.reload
        artist.group_name = "some_group"
        expect(artist).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # group_name — length
    # -------------------------------------------------------------------------
    describe "group_name length" do
      it "is invalid when group_name exceeds 100 characters" do
        artist = build(:artist, group_name: "a" * 101)
        expect(artist).not_to be_valid
        expect(artist.errors[:group_name]).to be_present
      end

      it "is valid with a group_name of exactly 100 characters" do
        expect(build(:artist, group_name: "a" * 100)).to be_valid
      end

      it "is valid with a blank group_name" do
        expect(build(:artist, group_name: "")).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validate_user_can_edit — locked artist guard
    # -------------------------------------------------------------------------
    describe "validate_user_can_edit" do
      it "allows a janitor to save a locked artist" do
        artist = create(:locked_artist)
        CurrentUser.user = create(:janitor_user)
        artist.group_name = "some_group"
        expect(artist).to be_valid
      end

      it "prevents a member from saving a locked artist" do
        artist = create(:locked_artist)
        CurrentUser.user = create(:user)
        artist.group_name = "some_group"
        expect(artist).not_to be_valid
        expect(artist.errors[:base]).to include("Artist is locked")
      end
    end

    # -------------------------------------------------------------------------
    # user_not_limited — rate-limit guard
    # -------------------------------------------------------------------------
    describe "user_not_limited" do
      it "is invalid for a newbie member when throttles are enabled" do
        allow(Danbooru.config.custom_configuration).to receive(:disable_throttles?).and_return(false)
        CurrentUser.user = create(:user, created_at: Time.now)
        artist = build(:artist)
        expect(artist).not_to be_valid
        expect(artist.errors[:base]).to be_present
      end

      it "is valid for an admin even when throttles are enabled" do
        allow(Danbooru.config.custom_configuration).to receive(:disable_throttles?).and_return(false)
        # CurrentUser is already an admin via include_context
        expect(build(:artist)).to be_valid
      end
    end
  end
end
