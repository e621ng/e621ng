# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Blip::PermissionsMethods                            #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  let(:creator)   { create(:user) }
  let(:other)     { create(:user) }
  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }

  before do
    CurrentUser.user    = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_blip(overrides = {})
    create(:blip, **overrides)
  end

  # -------------------------------------------------------------------------
  # #can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "allows an admin to edit any blip" do
      blip = make_blip
      expect(blip.can_edit?(admin)).to be true
    end

    it "denies editing a warned blip even for the creator" do
      blip = make_blip
      blip.user_warned!(:warning, moderator)
      expect(blip.can_edit?(creator)).to be false
    end

    it "allows the creator to edit within 5 minutes of creation" do
      blip = make_blip
      expect(blip.can_edit?(creator)).to be true
    end

    it "denies the creator from editing more than 5 minutes after creation" do
      blip = create(:blip, created_at: 10.minutes.ago)
      expect(blip.can_edit?(creator)).to be false
    end

    it "denies a non-creator non-admin from editing" do
      blip = make_blip
      expect(blip.can_edit?(other)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_delete?
  # -------------------------------------------------------------------------
  describe "#can_delete?" do
    it "allows a moderator to delete any blip" do
      blip = make_blip
      expect(blip.can_delete?(moderator)).to be true
    end

    it "denies deleting a warned blip even for the creator" do
      blip = make_blip
      blip.user_warned!(:warning, moderator)
      expect(blip.can_delete?(creator)).to be false
    end

    it "allows the creator to delete their own blip" do
      blip = make_blip
      expect(blip.can_delete?(creator)).to be true
    end

    it "denies a non-creator non-moderator from deleting" do
      blip = make_blip
      expect(blip.can_delete?(other)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #visible_to?
  # -------------------------------------------------------------------------
  describe "#visible_to?" do
    it "is visible to anyone when not deleted" do
      blip = make_blip
      expect(blip.visible_to?(other)).to be true
    end

    it "is visible to a moderator when deleted" do
      blip = make_blip
      blip.delete!
      expect(blip.visible_to?(moderator)).to be true
    end

    it "is visible to the creator when deleted" do
      blip = make_blip
      blip.delete!
      expect(blip.visible_to?(creator)).to be true
    end

    it "is not visible to an unrelated user when deleted" do
      blip = make_blip
      blip.delete!
      expect(blip.visible_to?(other)).to be false
    end
  end
end
