# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     ArtistVersion Factory Sanity Checks                     #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid artist_version with build" do
      expect(build(:artist_version)).to be_valid
    end

    it "produces a valid artist_version with create" do
      expect(create(:artist_version)).to be_persisted
    end
  end
end
