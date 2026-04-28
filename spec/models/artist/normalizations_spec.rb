# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist Normalizations                               #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # normalize_name (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_name" do
    it "downcases the name" do
      artist = create(:artist, name: generate(:artist_name).upcase)
      expect(artist.name).to eq(artist.name.downcase)
    end

    it "strips leading and trailing whitespace" do
      artist = build(:artist, name: "  spaced_name  ")
      artist.valid?
      expect(artist.name).to eq("spaced_name")
    end

    it "converts spaces to underscores" do
      artist = build(:artist, name: "some artist name")
      artist.valid?
      expect(artist.name).to eq("some_artist_name")
    end
  end

  # -------------------------------------------------------------------------
  # normalize_other_names (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_other_names" do
    it "normalizes each other name (downcase, underscores)" do
      artist = build(:artist, other_names: ["OTHER NAME"])
      artist.valid?
      expect(artist.other_names).to include("other_name")
    end

    it "deduplicates other_names" do
      artist = build(:artist, other_names: %w[same_name same_name])
      artist.valid?
      expect(artist.other_names.count("same_name")).to eq(1)
    end

    it "removes the artist's own name from other_names" do
      artist = build(:artist, name: "self_artist", other_names: %w[self_artist other_alias])
      artist.valid?
      expect(artist.other_names).not_to include("self_artist")
      expect(artist.other_names).to include("other_alias")
    end

    it "limits other_names to 25 entries" do
      artist = build(:artist, other_names: (1..30).map { |n| "alias_#{n}" })
      artist.valid?
      expect(artist.other_names.length).to eq(25)
    end

    it "truncates each other name to 100 characters" do
      long_name = "a" * 150
      artist = build(:artist, other_names: [long_name])
      artist.valid?
      expect(artist.other_names.first.length).to eq(100)
    end
  end
end
