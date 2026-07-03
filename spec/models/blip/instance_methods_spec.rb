# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Blip Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  include_context "as member"

  def make_blip(overrides = {})
    create(:blip, **overrides)
  end

  # -------------------------------------------------------------------------
  # #is_response?
  # -------------------------------------------------------------------------
  describe "#is_response?" do
    it "returns false when the blip has no parent" do
      blip = make_blip
      expect(blip.is_response?).to be false
    end

    it "returns true when the blip is a reply to another blip" do
      parent = make_blip
      reply  = make_blip(response_to: parent.id)
      expect(reply.is_response?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #has_responses?
  # -------------------------------------------------------------------------
  describe "#has_responses?" do
    it "returns false when the blip has no replies" do
      blip = make_blip
      expect(blip.has_responses?).to be false
    end

    it "returns true when at least one blip replies to this one" do
      parent = make_blip
      make_blip(response_to: parent.id)
      expect(parent.has_responses?).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #delete! / #undelete!
  # -------------------------------------------------------------------------
  describe "#delete!" do
    it "sets is_deleted to true" do
      blip = make_blip
      expect { blip.delete! }.to change { blip.reload.is_deleted }.from(false).to(true)
    end
  end

  describe "#undelete!" do
    it "sets is_deleted to false" do
      blip = make_blip(is_deleted: true)
      expect { blip.undelete! }.to change { blip.reload.is_deleted }.from(true).to(false)
    end
  end
end
