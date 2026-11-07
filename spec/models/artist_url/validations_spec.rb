# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ArtistUrl Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # url — presence
  # -------------------------------------------------------------------------
  describe "url presence" do
    it "is invalid when url is blank" do
      record = build(:artist_url, url: "")
      expect(record).not_to be_valid
      expect(record.errors[:url]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # url — uniqueness scoped to artist
  # -------------------------------------------------------------------------
  describe "url uniqueness" do
    it "is invalid when the same url already exists for the same artist" do
      artist = create(:artist)
      create(:artist_url, artist: artist, url: "http://example.com/duplicate/")
      duplicate = build(:artist_url, artist: artist, url: "http://example.com/duplicate/")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url]).to be_present
    end

    it "is valid when the same url is used for a different artist" do
      create(:artist_url, url: "http://example.com/shared/")
      other_artist = create(:artist)
      record = build(:artist_url, artist: other_artist, url: "http://example.com/shared/")
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # url — length (1..512)
  # -------------------------------------------------------------------------
  describe "url length" do
    it "is invalid when url exceeds 512 characters" do
      long_url = "http://example.com/#{'a' * (513 - 'http://example.com/'.length)}"
      record = build(:artist_url, url: long_url)
      expect(record).not_to be_valid
      expect(record.errors[:url]).to be_present
    end

    it "is valid at exactly 512 characters" do
      url512 = "http://example.com/#{'a' * (512 - 'http://example.com/'.length)}"
      expect(build(:artist_url, url: url512)).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # validate_url_format
  # -------------------------------------------------------------------------
  describe "url format" do
    it "is valid for an http:// url" do
      expect(build(:artist_url, url: "http://example.com/artist/")).to be_valid
    end

    it "is valid for an https:// url" do
      expect(build(:artist_url, url: "https://example.com/artist/")).to be_valid
    end

    it "is invalid for a non-http/https scheme" do
      record = build(:artist_url, url: "ftp://example.com/artist/")
      expect(record).not_to be_valid
      expect(record.errors[:url]).to be_present
    end

    it "is invalid for a malformed url" do
      record = build(:artist_url, url: "http:")
      expect(record).not_to be_valid
      expect(record.errors[:url]).to be_present
    end
  end
end
