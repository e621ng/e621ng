# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       AvoidPosting Factory Sanity Checks                    #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  describe "factory" do
    it "produces a valid avoid_posting with build" do
      expect(build(:avoid_posting)).to be_valid
    end

    it "produces a valid avoid_posting with create" do
      expect(create(:avoid_posting)).to be_persisted
    end

    it "produces a valid inactive_avoid_posting" do
      dnp = create(:inactive_avoid_posting)
      expect(dnp).to be_persisted
      expect(dnp.is_active).to be false
    end
  end
end
