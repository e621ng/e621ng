# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Artist::NameMethods                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .normalize_name (class method)
  # -------------------------------------------------------------------------
  describe ".normalize_name" do
    it "converts to lowercase" do
      expect(Artist.normalize_name("UPPER_CASE")).to eq("upper_case")
    end

    it "strips surrounding whitespace" do
      expect(Artist.normalize_name("  spaced  ")).to eq("spaced")
    end

    it "replaces spaces with underscores" do
      expect(Artist.normalize_name("artist name")).to eq("artist_name")
    end

    it "returns an empty string when given nil" do
      expect(Artist.normalize_name(nil)).to eq("")
    end

    it "returns an already-normalized name unchanged" do
      expect(Artist.normalize_name("already_normalized")).to eq("already_normalized")
    end
  end

  # -------------------------------------------------------------------------
  # .named
  # -------------------------------------------------------------------------
  describe ".named" do
    it "finds an artist by exact normalized name" do
      artist = create(:artist, name: "find_me")
      expect(Artist.named("find_me")).to eq(artist)
    end

    it "is case-insensitive" do
      artist = create(:artist, name: "case_test")
      expect(Artist.named("CASE_TEST")).to eq(artist)
    end

    it "treats spaces as underscores" do
      artist = create(:artist, name: "spaced_name")
      expect(Artist.named("spaced name")).to eq(artist)
    end

    it "returns nil when no artist matches" do
      expect(Artist.named("nonexistent_artist")).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #pretty_name
  # -------------------------------------------------------------------------
  describe "#pretty_name" do
    it "replaces underscores with spaces" do
      artist = build(:artist, name: "some_artist_name")
      expect(artist.pretty_name).to eq("some artist name")
    end

    it "returns the name unchanged when there are no underscores" do
      artist = build(:artist, name: "artist")
      expect(artist.pretty_name).to eq("artist")
    end
  end

  # -------------------------------------------------------------------------
  # #member_names (GroupMethods)
  # -------------------------------------------------------------------------
  describe "#member_names" do
    it "returns a comma-joined string of member names" do
      group = create(:artist, name: "the_group")
      _m1 = create(:artist, group_name: "the_group")
      _m2 = create(:artist, group_name: "the_group")
      names = group.member_names
      expect(names.split(", ").length).to eq(2)
    end

    it "returns an empty string when the artist has no members" do
      artist = create(:artist)
      expect(artist.member_names).to eq("")
    end

    it "limits to 25 members" do
      group = create(:artist, name: "big_group")
      26.times { create(:artist, group_name: "big_group") }
      expect(group.member_names.split(", ").length).to eq(25)
    end
  end
end
