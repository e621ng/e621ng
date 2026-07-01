# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                             Factory sanity checks                           #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"

  describe "factory" do
    it "produces a valid general tag" do
      expect(build(:tag)).to be_valid
    end

    it "produces a valid artist tag" do
      expect(build(:artist_tag)).to be_valid
    end

    it "produces a valid copyright tag" do
      expect(build(:copyright_tag)).to be_valid
    end

    it "produces a valid character tag" do
      expect(build(:character_tag)).to be_valid
    end

    it "produces a valid species tag" do
      expect(build(:species_tag)).to be_valid
    end

    it "produces a valid locked tag" do
      expect(build(:locked_tag)).to be_valid
    end

    it "produces a valid high post count tag" do
      expect(build(:high_post_count_tag)).to be_valid
    end
  end
end
