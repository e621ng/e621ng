# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        AvoidPosting Permissions                             #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  def make_dnp(overrides = {})
    create(:avoid_posting, **overrides)
  end

  # -------------------------------------------------------------------------
  # #hidden_attributes — staff_notes visibility
  # -------------------------------------------------------------------------
  describe "#hidden_attributes" do
    it "includes :staff_notes for a non-staff user" do
      CurrentUser.user = create(:user)
      dnp = make_dnp
      expect(dnp.hidden_attributes).to include(:staff_notes)
    end

    it "does not include :staff_notes for a janitor" do
      CurrentUser.user = create(:janitor_user)
      dnp = make_dnp
      expect(dnp.hidden_attributes).not_to include(:staff_notes)
    end
  end

  # -------------------------------------------------------------------------
  # Artist name protection (via AvoidPostingMethods on Artist)
  # -------------------------------------------------------------------------
  describe "artist name protection" do
    let(:artist) { create(:artist) }
    let!(:dnp)   { make_dnp(artist: artist) }

    # `validates_associated :artist` during DNP creation calls artist.valid?, which
    # loads and caches `avoid_posting` as nil (it doesn't exist yet at validation time).
    # Reload clears that stale cache so is_dnp? reflects the persisted DNP record.
    before { artist.reload }

    it "prevents a non-bd_staff user from changing the artist's name while DNP is active" do
      CurrentUser.user = create(:user)
      artist.name = "#{artist.name}_changed"
      expect(artist).not_to be_valid
      expect(artist.errors[:name]).to include("cannot be changed while the artist is on the avoid posting list")
    end

    it "allows a bd_staff user to change the artist's name even with an active DNP" do
      CurrentUser.user = create(:user, is_bd_staff: true)
      artist.name = "#{artist.name}_changed"
      expect(artist).to be_valid
    end

    it "allows name change when the DNP entry is inactive" do
      CurrentUser.user = create(:user)
      dnp.update_columns(is_active: false)
      artist.reload
      artist.name = "#{artist.name}_changed"
      expect(artist).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # Artist deletability when a DNP entry exists
  # -------------------------------------------------------------------------
  describe "artist deletability with DNP" do
    it "prevents an admin from deleting an artist with an active DNP entry" do
      admin  = create(:admin_user)
      artist = create(:artist)
      make_dnp(artist: artist)
      artist.reload
      expect(artist.deletable_by?(admin)).to be false
    end

    it "prevents an admin from deleting an artist with only an inactive DNP entry" do
      admin  = create(:admin_user)
      artist = create(:artist)
      create(:inactive_avoid_posting, artist: artist)
      artist.reload
      expect(artist.deletable_by?(admin)).to be false
    end
  end
end
