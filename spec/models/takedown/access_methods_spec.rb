# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Takedown AccessMethods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  subject(:takedown) { create(:takedown) }

  include_context "as admin"

  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member)    { create(:user) }

  # -------------------------------------------------------------------------
  # can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "returns true for an admin" do
      expect(takedown.can_edit?(admin)).to be true
    end

    it "returns false for a moderator" do
      expect(takedown.can_edit?(moderator)).to be false
    end

    it "returns false for a regular member" do
      expect(takedown.can_edit?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # can_delete?
  # -------------------------------------------------------------------------
  describe "#can_delete?" do
    it "returns true for an admin" do
      expect(takedown.can_delete?(admin)).to be true
    end

    it "returns false for a moderator" do
      expect(takedown.can_delete?(moderator)).to be false
    end

    it "returns false for a regular member" do
      expect(takedown.can_delete?(member)).to be false
    end
  end
end
