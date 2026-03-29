# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      ArtistVersion Instance Methods                         #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil when there are no earlier versions of the artist" do
      artist = create(:artist)
      first_version = artist.versions.first
      expect(first_version.previous).to be_nil
    end

    it "returns the immediately preceding version of the same artist" do
      artist = create(:artist, name: "ver_artist_one")
      first_version = artist.versions.first

      artist.update!(name: "ver_artist_two")
      second_version = artist.versions.order(:created_at).last

      expect(second_version.previous).to eq(first_version)
    end

    it "does not return a version belonging to a different artist" do
      artist_a = create(:artist)
      artist_b = create(:artist)

      # Give artist_b's version an earlier created_at so it would be returned
      # if #previous failed to filter by artist_id.
      artist_b.versions.first.update_columns(created_at: 1.hour.ago)

      artist_a.update!(name: "#{artist_a.name}_v2")
      second_version = artist_a.versions.order(:created_at).last

      expect(second_version.previous).not_to eq(artist_b.versions.first)
      expect(second_version.previous.artist_id).to eq(artist_a.id)
    end
  end

  # -------------------------------------------------------------------------
  # array_attribute :urls
  # -------------------------------------------------------------------------
  describe "urls array attribute" do
    it "round-trips an array of URLs after persist and reload" do
      version = create(:artist_version, urls: ["https://example.com", "https://other.com"])
      expect(version.reload.urls).to eq(["https://example.com", "https://other.com"])
    end

    it "defaults to an empty array when not set" do
      version = create(:artist_version)
      expect(version.reload.urls).to eq([])
    end
  end

  # -------------------------------------------------------------------------
  # array_attribute :other_names
  # -------------------------------------------------------------------------
  describe "other_names array attribute" do
    it "round-trips an array of names after persist and reload" do
      version = create(:artist_version, other_names: %w[alias_one alias_two])
      expect(version.reload.other_names).to eq(%w[alias_one alias_two])
    end

    it "defaults to an empty array when not set" do
      version = create(:artist_version)
      expect(version.reload.other_names).to eq([])
    end
  end
end
