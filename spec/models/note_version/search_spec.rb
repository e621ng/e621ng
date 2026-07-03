# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         NoteVersion Search                                  #
# --------------------------------------------------------------------------- #

RSpec.describe NoteVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # Shared fixtures
  # -------------------------------------------------------------------------
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }

  # Two baseline versions, each created by a distinct user.
  let!(:version_a) do
    note = CurrentUser.scoped(user_a, "127.0.0.1") { create(:note, body: "unique alpha body") }
    note.versions.last
  end

  let!(:version_b) do
    note = CurrentUser.scoped(user_b, "127.0.0.1") { create(:note, body: "unique beta body") }
    note.versions.last
  end

  # -------------------------------------------------------------------------
  # updater_id param
  # -------------------------------------------------------------------------
  describe "updater_id param" do
    it "returns versions by the specified updater" do
      result = NoteVersion.search(updater_id: user_a.id.to_s)
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end
  end

  # -------------------------------------------------------------------------
  # updater_name param
  # -------------------------------------------------------------------------
  describe "updater_name param" do
    it "returns versions by the specified updater name" do
      result = NoteVersion.search(updater_name: user_a.name)
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end
  end

  # -------------------------------------------------------------------------
  # post_id param
  # -------------------------------------------------------------------------
  describe "post_id param" do
    it "filters versions by a single post id" do
      result = NoteVersion.search(post_id: version_a.post_id.to_s)
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end

    it "filters versions by multiple comma-separated post ids" do
      result = NoteVersion.search(post_id: "#{version_a.post_id},#{version_b.post_id}")
      expect(result).to include(version_a, version_b)
    end
  end

  # -------------------------------------------------------------------------
  # note_id param
  # -------------------------------------------------------------------------
  describe "note_id param" do
    it "filters versions by a single note id" do
      result = NoteVersion.search(note_id: version_a.note_id.to_s)
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end

    it "filters versions by multiple comma-separated note ids" do
      result = NoteVersion.search(note_id: "#{version_a.note_id},#{version_b.note_id}")
      expect(result).to include(version_a, version_b)
    end
  end

  # -------------------------------------------------------------------------
  # is_active param
  # -------------------------------------------------------------------------
  describe "is_active param" do
    let!(:version_inactive) do
      note = CurrentUser.scoped(user_a, "127.0.0.1") { create(:note) }
      note.update!(is_active: false)
      note.versions.last
    end

    it "returns only active versions when is_active is 'true'" do
      result = NoteVersion.search(is_active: "true")
      expect(result).to include(version_a)
      expect(result).not_to include(version_inactive)
    end

    it "returns only inactive versions when is_active is 'false'" do
      result = NoteVersion.search(is_active: "false")
      expect(result).to include(version_inactive)
      expect(result).not_to include(version_a)
    end
  end

  # -------------------------------------------------------------------------
  # body_matches param
  # -------------------------------------------------------------------------
  describe "body_matches param" do
    it "returns versions whose body matches the search term" do
      result = NoteVersion.search(body_matches: "alpha")
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end

    it "supports a trailing wildcard" do
      result = NoteVersion.search(body_matches: "unique alpha*")
      expect(result).to include(version_a)
      expect(result).not_to include(version_b)
    end
  end

  # -------------------------------------------------------------------------
  # ip_addr param (CIDR subnet matching)
  # -------------------------------------------------------------------------
  describe "ip_addr param" do
    let!(:version_custom_ip) do
      note = CurrentUser.scoped(user_a, "127.0.0.1") { create(:note, body: "custom ip note") }
      v = note.versions.last
      v.update_columns(updater_ip_addr: "10.0.0.5")
      v
    end

    it "returns versions whose updater_ip_addr falls within the given CIDR block" do
      result = NoteVersion.search(ip_addr: "10.0.0.0/24")
      expect(result).to include(version_custom_ip)
    end

    it "excludes versions outside the given CIDR block" do
      result = NoteVersion.search(ip_addr: "10.0.0.0/24")
      expect(result).not_to include(version_a)
    end

    it "matches a single IP address exactly" do
      result = NoteVersion.search(ip_addr: "10.0.0.5")
      expect(result).to include(version_custom_ip)
    end
  end
end
