# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaffWiki do
  include_context "as janitor"

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  describe "validations" do
    describe "title — presence" do
      it "is invalid when title is nil" do
        page = build(:staff_wiki, title: nil)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is invalid when title is a blank string" do
        page = build(:staff_wiki, title: "")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end
    end

    describe "title — uniqueness" do
      it "is invalid when a page with the same lowercased title already exists" do
        create(:staff_wiki, title: "duplicate_page")
        page = build(:staff_wiki, title: "duplicate_page")
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is valid when the title is unique" do
        create(:staff_wiki, title: "existing_page")
        page = build(:staff_wiki, title: "new_page")
        expect(page).to be_valid
      end
    end

    describe "title — length" do
      it "is invalid when the title exceeds 100 characters" do
        page = build(:staff_wiki, title: "a" * 101)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to be_present
      end

      it "is valid at exactly 100 characters" do
        page = build(:staff_wiki, title: "a" * 100)
        expect(page).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Normalizations
  # ---------------------------------------------------------------------------

  describe "normalizations" do
    describe "title" do
      it "lowercases the title" do
        page = create(:staff_wiki, title: "My_Page")
        expect(page.title).to eq("my_page")
      end

      it "converts spaces to underscores" do
        page = create(:staff_wiki, title: "my staff page")
        expect(page.title).to eq("my_staff_page")
      end
    end

    describe "body" do
      it "normalizes CRLF line endings to LF" do
        page = create(:staff_wiki, body: "line one\r\nline two")
        expect(page.body).to eq("line one\nline two")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Versioning
  # ---------------------------------------------------------------------------

  describe "versioning" do
    it "creates a version after create" do
      page = create(:staff_wiki)
      expect(page.versions.count).to eq(1)
    end

    it "creates another version after a body change" do
      page = create(:staff_wiki)
      page.update!(body: "updated body")
      expect(page.versions.count).to eq(2)
    end

    it "creates another version after a title change" do
      page = create(:staff_wiki)
      page.update!(title: "new_title_#{SecureRandom.hex(4)}")
      expect(page.versions.count).to eq(2)
    end

    it "does not create a version when nothing tracked changes" do
      page = create(:staff_wiki)
      page.update!(edit_reason: "just a reason, no content change")
      expect(page.versions.count).to eq(1)
    end

    it "snapshots the title and body into the version" do
      page = create(:staff_wiki, title: "snapshot_test", body: "original body")
      version = page.versions.last
      expect(version.title).to eq("snapshot_test")
      expect(version.body).to eq("original body")
    end

    it "stores the edit reason on the version" do
      page = create(:staff_wiki)
      page.edit_reason = "important fix"
      page.update!(body: "new body")
      expect(page.versions.last.reason).to eq("important fix")
    end
  end

  # ---------------------------------------------------------------------------
  # Instance methods
  # ---------------------------------------------------------------------------

  describe "#pretty_title" do
    it "replaces underscores with spaces" do
      page = build(:staff_wiki, title: "my_staff_page")
      page.instance_variable_set(:@title, "my_staff_page")
      expect(page.pretty_title).to eq("my staff page")
    end

    it "returns empty string when title is nil" do
      page = build(:staff_wiki)
      page.title = nil
      expect(page.pretty_title).to eq("")
    end
  end

  describe "#revert_to" do
    it "restores title and body from the version" do
      page = create(:staff_wiki, title: "original_title", body: "original body")
      version = page.versions.last
      page.update!(body: "changed body")
      page.revert_to(version)
      expect(page.title).to eq("original_title")
      expect(page.body).to eq("original body")
    end

    it "raises RevertError when the version belongs to a different page" do
      page_a = create(:staff_wiki)
      page_b = create(:staff_wiki)
      version_b = page_b.versions.last
      expect { page_a.revert_to(version_b) }.to raise_error(StaffWiki::RevertError)
    end
  end

  describe "#revert_to!" do
    it "saves the reverted content" do
      page = create(:staff_wiki, body: "original body")
      version = page.versions.last
      page.update!(body: "changed body")
      page.revert_to!(version)
      expect(page.reload.body).to eq("original body")
    end
  end

  describe ".normalize_name" do
    it "lowercases and replaces spaces with underscores" do
      expect(StaffWiki.normalize_name("My Staff Page")).to eq("my_staff_page")
    end

    it "returns nil for nil input" do
      expect(StaffWiki.normalize_name(nil)).to be_nil
    end
  end

  describe ".titled" do
    it "finds a page by its normalized title" do
      page = create(:staff_wiki, title: "findable_page")
      expect(StaffWiki.titled("findable_page")).to eq(page)
    end

    it "returns nil when no page exists" do
      expect(StaffWiki.titled("does_not_exist_xyz")).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Search
  # ---------------------------------------------------------------------------

  describe ".search" do
    let!(:page_alpha) { create(:staff_wiki, title: "alpha_guide") }
    let!(:page_beta)  { create(:staff_wiki, title: "beta_guide", body: "contains secret") }

    it "filters by title with ILIKE" do
      results = StaffWiki.search(title: "alpha*")
      expect(results).to include(page_alpha)
      expect(results).not_to include(page_beta)
    end

    it "filters by body content" do
      results = StaffWiki.search(body_matches: "secret")
      expect(results).to include(page_beta)
      expect(results).not_to include(page_alpha)
    end

    it "orders by title when order=title" do
      results = StaffWiki.search(order: "title").to_a
      titles = results.map(&:title)
      expect(titles).to eq(titles.sort)
    end
  end
end
