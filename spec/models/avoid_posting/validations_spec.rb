# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        AvoidPosting Validations                             #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  describe "validations" do
    # -------------------------------------------------------------------------
    # artist_id — uniqueness
    # -------------------------------------------------------------------------
    describe "artist_id uniqueness" do
      it "is invalid when an avoid posting entry already exists for the same artist" do
        artist = create(:artist)
        create(:avoid_posting, artist: artist)
        duplicate = build(:avoid_posting, artist: artist)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:artist_id]).to be_present
      end

      it "is valid for different artists" do
        create(:avoid_posting)
        expect(build(:avoid_posting)).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # validates_associated :artist
    # -------------------------------------------------------------------------
    describe "validates_associated :artist" do
      it "is invalid when the associated artist is invalid" do
        dnp = build(:avoid_posting)
        dnp.artist.name = "a" * 101
        expect(dnp).not_to be_valid
        expect(dnp.errors[:artist]).to be_present
      end
    end
  end
end
