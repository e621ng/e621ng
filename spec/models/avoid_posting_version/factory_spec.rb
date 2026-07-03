# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    AvoidPostingVersion Factory Sanity Checks                #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPostingVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid avoid_posting_version with build" do
      expect(build(:avoid_posting_version)).to be_valid
    end

    it "produces a valid avoid_posting_version with create" do
      expect(create(:avoid_posting_version)).to be_persisted
    end
  end
end
