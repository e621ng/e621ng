# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffWikiVersion do
  include_context "as janitor"

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

  describe "#pretty_title" do
    it "replaces underscores with spaces" do
      version = build(:staff_wiki_version, title: "my_staff_page")
      expect(version.pretty_title).to eq("my staff page")
    end
  end

  describe "#previous" do
    it "returns nil when there is no earlier version" do
      page = create(:staff_wiki)
      first_version = page.versions.first
      expect(first_version.previous).to be_nil
    end

    it "returns the immediately preceding version" do
      page = create(:staff_wiki)
      page.update!(body: "second version")
      versions = page.versions.order(:id).to_a
      expect(versions.second.previous).to eq(versions.first)
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  describe ".search" do
    let!(:page)    { create(:staff_wiki) }
    let!(:version) { page.versions.last }

    it "filters by staff_wiki_id" do
      other_page = create(:staff_wiki)
      results = StaffWikiVersion.search(staff_wiki_id: page.id)
      expect(results).to include(version)
      expect(results).not_to include(other_page.versions.last)
    end

    it "filters by title" do
      results = StaffWikiVersion.search(title: version.title)
      expect(results).to include(version)
    end

    it "filters by body" do
      results = StaffWikiVersion.search(body: "Staff wiki body.")
      expect(results).to include(version)
    end
  end

  describe ".search — ip_addr" do
    let!(:page)    { create(:staff_wiki) }
    let!(:version) { page.versions.last }

    context "as admin" do
      include_context "as admin"

      it "filters by IP address" do
        results = StaffWikiVersion.search(ip_addr: "127.0.0.1/32")
        expect(results).to include(version)
      end
    end
  end
end
