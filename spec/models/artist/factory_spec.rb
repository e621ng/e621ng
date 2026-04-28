# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Artist Factory Sanity Checks                      #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  describe "factory" do
    it "produces a valid artist with build" do
      expect(build(:artist)).to be_valid
    end

    it "produces a valid artist with create" do
      expect(create(:artist)).to be_persisted
    end

    it "produces a valid locked artist" do
      artist = create(:locked_artist)
      expect(artist).to be_persisted
      expect(artist.is_locked).to be true
    end

    it "produces a valid inactive artist" do
      artist = create(:inactive_artist)
      expect(artist).to be_persisted
      expect(artist.is_active).to be false
    end
  end
end
