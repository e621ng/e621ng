# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ArtistUrl Normalizations                             #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistUrl do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .normalize (class method)
  # -------------------------------------------------------------------------
  describe ".normalize" do
    it "returns nil when given nil" do
      expect(ArtistUrl.normalize(nil)).to be_nil
    end

    it "converts https:// to http://" do
      expect(ArtistUrl.normalize("https://example.com/artist/")).to eq("http://example.com/artist/")
    end

    it "downcases the domain portion of the url" do
      expect(ArtistUrl.normalize("http://EXAMPLE.COM/Artist/")).to eq("http://example.com/Artist/")
    end

    it "strips multiple trailing slashes and appends a single one" do
      expect(ArtistUrl.normalize("http://example.com/artist///")).to eq("http://example.com/artist/")
    end

    it "appends a trailing slash when none is present" do
      expect(ArtistUrl.normalize("http://example.com/artist")).to eq("http://example.com/artist/")
    end

    it "does not double-encode an already-normalized url" do
      normalized = "http://example.com/artist/"
      expect(ArtistUrl.normalize(normalized)).to eq(normalized)
    end
  end

  # -------------------------------------------------------------------------
  # #normalize (instance — before_validation, always)
  # -------------------------------------------------------------------------
  describe "#normalize" do
    it "sets normalized_url to the normalized form of url" do
      record = build(:artist_url, url: "https://EXAMPLE.COM/artist///")
      record.valid?
      expect(record.normalized_url).to eq("http://example.com/artist/")
    end

    it "re-normalizes normalized_url on update" do
      record = create(:artist_url, url: "http://example.com/before/")
      record.update!(url: "https://EXAMPLE.COM/after///")
      expect(record.normalized_url).to eq("http://example.com/after/")
    end
  end

  # -------------------------------------------------------------------------
  # #initialize_normalized_url (before_validation, on: :create only)
  # -------------------------------------------------------------------------
  describe "#initialize_normalized_url" do
    it "sets normalized_url to the raw url value before normalization fires on a new record" do
      # We can observe this indirectly: normalized_url after a full save is the
      # normalized form, not the raw value — but the callback chain ensures the
      # column is never nil after create even when normalize would shortcircuit.
      record = create(:artist_url, url: "http://example.com/init/")
      expect(record.normalized_url).not_to be_nil
    end
  end
end
