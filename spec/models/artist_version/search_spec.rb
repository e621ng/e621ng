# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          ArtistVersion Search                               #
# --------------------------------------------------------------------------- #

RSpec.describe ArtistVersion do
  include_context "as admin"

  # Versions are created automatically via Artist callbacks.
  # Each create(:artist) produces exactly one ArtistVersion.
  let!(:artist_alpha)    { create(:artist, name: "srch_alpha", group_name: "group_a") }
  let!(:artist_beta)     { create(:artist, name: "srch_beta",  group_name: "group_b") }
  let!(:artist_inactive) { create(:inactive_artist, name: "srch_inactive") }

  let(:version_alpha)    { artist_alpha.versions.first }
  let(:version_beta)     { artist_beta.versions.first }
  let(:version_inactive) { artist_inactive.versions.first }

  # -------------------------------------------------------------------------
  # name param
  # -------------------------------------------------------------------------
  describe "name param" do
    it "returns the version with a matching name" do
      result = ArtistVersion.search(name: "srch_alpha")
      expect(result).to include(version_alpha)
      expect(result).not_to include(version_beta)
    end

    it "excludes versions whose name does not match" do
      result = ArtistVersion.search(name: "srch_beta")
      expect(result).not_to include(version_alpha)
    end

    it "supports a trailing wildcard" do
      result = ArtistVersion.search(name: "srch_*")
      expect(result).to include(version_alpha, version_beta, version_inactive)
    end
  end

  # -------------------------------------------------------------------------
  # updater_name / updater_id params (via where_user)
  # -------------------------------------------------------------------------
  describe "updater_name param" do
    it "returns only versions updated by the given user" do
      other_user = create(:user)
      CurrentUser.user = other_user
      artist_other = create(:artist, name: "srch_other_user")
      CurrentUser.user = create(:admin_user)

      result = ArtistVersion.search(updater_name: other_user.name)
      expect(result).to include(artist_other.versions.first)
      expect(result).not_to include(version_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # artist_id param
  # -------------------------------------------------------------------------
  describe "artist_id param" do
    it "returns only the version for the given artist_id" do
      result = ArtistVersion.search(artist_id: artist_alpha.id.to_s)
      expect(result).to include(version_alpha)
      expect(result).not_to include(version_beta)
    end

    it "accepts comma-separated artist_ids" do
      result = ArtistVersion.search(artist_id: "#{artist_alpha.id},#{artist_beta.id}")
      expect(result).to include(version_alpha, version_beta)
      expect(result).not_to include(version_inactive)
    end
  end

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    it "returns only active versions when is_active is true" do
      result = ArtistVersion.search(is_active: "true")
      expect(result).to include(version_alpha, version_beta)
      expect(result).not_to include(version_inactive)
    end

    it "returns only inactive versions when is_active is false" do
      result = ArtistVersion.search(is_active: "false")
      expect(result).to include(version_inactive)
      expect(result).not_to include(version_alpha, version_beta)
    end
  end

  # -------------------------------------------------------------------------
  # ip_addr param
  # -------------------------------------------------------------------------
  describe "ip_addr param" do
    it "returns versions whose updater_ip_addr falls within the given CIDR" do
      # The shared 'as admin' context sets CurrentUser.ip_addr = "127.0.0.1",
      # so all versions created above have updater_ip_addr = "127.0.0.1".
      result = ArtistVersion.search(ip_addr: "127.0.0.1")
      expect(result).to include(version_alpha, version_beta)
    end

    it "excludes versions outside the given CIDR" do
      result = ArtistVersion.search(ip_addr: "192.168.0.0/24")
      expect(result).not_to include(version_alpha)
    end
  end

  # -------------------------------------------------------------------------
  # order param
  # -------------------------------------------------------------------------
  describe "order param" do
    it "orders by name when order is 'name'" do
      names = ArtistVersion.search(order: "name").pluck(:name)
      srch_names = names.select { |n| n.start_with?("srch_") }
      expect(srch_names).to eq(srch_names.sort)
    end

    it "defaults to newest first" do
      ids = ArtistVersion.search({}).ids
      expect(ids.index(version_inactive.id)).to be < ids.index(version_alpha.id)
    end
  end

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    it "returns versions where updater_id matches the given user" do
      other_user = create(:user)
      CurrentUser.user = other_user
      artist_for_user = create(:artist, name: "srch_for_user")
      CurrentUser.user = create(:admin_user)

      result = ArtistVersion.for_user(other_user.id)
      expect(result).to include(artist_for_user.versions.first)
    end

    it "excludes versions from other updaters" do
      other_user = create(:user)
      result = ArtistVersion.for_user(other_user.id)
      expect(result).not_to include(version_alpha)
    end
  end
end
