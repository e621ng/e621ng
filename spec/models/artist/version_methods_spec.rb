# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Artist::VersionMethods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Artist do
  include_context "as admin"

  def make_artist(overrides = {})
    create(:artist, **overrides)
  end

  # -------------------------------------------------------------------------
  # create_version (after_save)
  # -------------------------------------------------------------------------
  describe "#create_version" do
    it "creates an ArtistVersion when the artist is first created" do
      expect { make_artist }.to change(ArtistVersion, :count).by(1)
    end

    it "creates a new version when the name changes" do
      artist = make_artist
      expect { artist.update!(name: "#{artist.name}_renamed") }.to change(ArtistVersion, :count).by(1)
    end

    it "creates a new version when other_names changes" do
      artist = make_artist
      expect { artist.update!(other_names: ["some_alias"]) }.to change(ArtistVersion, :count).by(1)
    end

    it "creates a new version when group_name changes" do
      artist = make_artist
      expect { artist.update!(group_name: "new_group") }.to change(ArtistVersion, :count).by(1)
    end

    it "creates a new version when notes change" do
      artist = make_artist
      expect { artist.update!(notes: "new notes") }.to change(ArtistVersion, :count).by(1)
    end

    it "does not create a new version when an untracked field changes" do
      artist = make_artist
      # is_active is not tracked for versioning
      expect { artist.update!(is_active: false) }.not_to change(ArtistVersion, :count)
    end

    it "records the current updater on the version" do
      artist = make_artist
      version = ArtistVersion.where(artist_id: artist.id).last
      expect(version.updater_id).to eq(CurrentUser.id)
    end
  end

  # -------------------------------------------------------------------------
  # #revert_to!
  # -------------------------------------------------------------------------
  describe "#revert_to!" do
    it "restores name, other_names, and group_name from a prior version" do
      artist = make_artist(name: "original_name", other_names: ["alias_one"], group_name: "orig_group")
      original_version = artist.versions.first

      artist.update!(name: "changed_name", other_names: ["alias_two"], group_name: "new_group")
      artist.revert_to!(original_version)
      artist.reload

      expect(artist.name).to eq("original_name")
      expect(artist.other_names).to eq(["alias_one"])
      expect(artist.group_name).to eq("orig_group")
    end

    it "raises RevertError when the version belongs to a different artist" do
      artist_a = make_artist
      artist_b = make_artist
      version_b = artist_b.versions.first

      expect { artist_a.revert_to!(version_b) }.to raise_error(Artist::RevertError)
    end

    it "creates a new version after reverting" do
      artist = make_artist(name: "revert_me")
      original_version = artist.versions.first
      artist.update!(name: "#{artist.name}_v2")

      expect { artist.revert_to!(original_version) }.to change(ArtistVersion, :count).by(1)
    end
  end
end
