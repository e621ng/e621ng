# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Artist Permissions                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # #deletable_by?
  # -------------------------------------------------------------------------
  describe "#deletable_by?" do
    it "returns true for an admin when the artist has no DNP entry" do
      admin = create(:admin_user)
      expect(make_artist.deletable_by?(admin)).to be true
    end

    it "returns false for a non-admin even without a DNP entry" do
      expect(make_artist.deletable_by?(create(:user))).to be false
      expect(make_artist.deletable_by?(create(:janitor_user))).to be false
      expect(make_artist.deletable_by?(create(:moderator_user))).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #editable_by?
  # -------------------------------------------------------------------------
  describe "#editable_by?" do
    it "returns true for a janitor when the artist is locked" do
      expect(create(:locked_artist).editable_by?(create(:janitor_user))).to be true
    end

    it "returns true for a janitor when the artist is unlocked" do
      expect(make_artist.editable_by?(create(:janitor_user))).to be true
    end

    it "returns true for a member when the artist is unlocked" do
      expect(make_artist.editable_by?(create(:user))).to be true
    end

    it "returns false for a member when the artist is locked" do
      expect(create(:locked_artist).editable_by?(create(:user))).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #visible?
  # -------------------------------------------------------------------------
  describe "#visible?" do
    it "always returns true" do
      expect(make_artist.visible?).to be true
      expect(create(:locked_artist).visible?).to be true
      expect(create(:inactive_artist).visible?).to be true
    end
  end
end
