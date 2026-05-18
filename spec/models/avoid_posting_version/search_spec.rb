# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       AvoidPostingVersion Search                            #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPostingVersion do
  include_context "as admin"

  # Versions are created automatically via AvoidPosting callbacks.
  # Each create(:avoid_posting) produces exactly one version.
  let!(:dnp_alpha)   { create(:avoid_posting, artist: create(:artist, name: "ver_alpha"), details: "contact first") }
  let!(:dnp_beta)    { create(:avoid_posting, artist: create(:artist, name: "ver_beta"),  details: "") }
  let!(:dnp_deleted) { create(:inactive_avoid_posting, artist: create(:artist, name: "ver_deleted")) }

  let(:version_alpha)   { dnp_alpha.versions.first }
  let(:version_beta)    { dnp_beta.versions.first }
  let(:version_deleted) { dnp_deleted.versions.first }

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only active versions when is_active is true" do
      result = AvoidPostingVersion.search(is_active: "true")
      expect(result).to include(version_alpha, version_beta)
      expect(result).not_to include(version_deleted)
    end

    it "returns only inactive versions when is_active is false" do
      result = AvoidPostingVersion.search(is_active: "false")
      expect(result).to include(version_deleted)
      expect(result).not_to include(version_alpha, version_beta)
    end
  end

  # -------------------------------------------------------------------------
  # artist_name param
  # -------------------------------------------------------------------------
  describe "artist_name param" do
    it "returns versions for the matching artist name" do
      result = AvoidPostingVersion.search(artist_name: "ver_alpha")
      expect(result).to include(version_alpha)
      expect(result).not_to include(version_beta)
    end
  end

  # -------------------------------------------------------------------------
  # any_name_matches param
  # -------------------------------------------------------------------------
  describe "any_name_matches param" do
    it "supports wildcard matching across artist names" do
      result = AvoidPostingVersion.search(any_name_matches: "ver_*")
      expect(result).to include(version_alpha, version_beta)
    end

    it "excludes non-matching artist names" do
      result = AvoidPostingVersion.search(any_name_matches: "ver_alpha")
      expect(result).not_to include(version_beta)
    end
  end

  # -------------------------------------------------------------------------
  # updater param
  # -------------------------------------------------------------------------
  describe "updater param" do
    it "returns only versions updated by the given user" do
      other_user = create(:user)
      # Create a version whose updater is other_user.
      CurrentUser.user = other_user
      dnp_other = create(:avoid_posting, artist: create(:artist, name: "ver_other"))
      CurrentUser.user = create(:admin_user)

      result = AvoidPostingVersion.search(updater_name: other_user.name)
      expect(result).to include(dnp_other.versions.first)
      expect(result).not_to include(version_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # ordering
  # -------------------------------------------------------------------------
  describe "order param" do
    it "defaults to newest first (id desc)" do
      ids = AvoidPostingVersion.search({}).ids
      expect(ids.index(version_deleted.id)).to be < ids.index(version_alpha.id)
    end
  end
end
