# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Blip Factory                                      #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  include_context "as member"

  describe "factory" do
    it "produces a valid blip with build" do
      blip = build(:blip)
      expect(blip).to be_valid, blip.errors.full_messages.join(", ")
    end

    it "produces a valid blip with create" do
      blip = create(:blip)
      expect(blip).to be_persisted
    end
  end
end
