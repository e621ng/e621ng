# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         HelpPage Class Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .pretty_related_title
  # -------------------------------------------------------------------------
  describe ".pretty_related_title" do
    let(:help_pages) do
      [
        build(:help_page, name: "uploading", title: "Uploading Guide"),
        build(:help_page, name: "tagging",   title: ""),
      ]
    end

    it "returns the matching help page's pretty_title when a page with that name exists" do
      expect(HelpPage.pretty_related_title("uploading", help_pages)).to eq("Uploading Guide")
    end

    it "falls back to the related string titleized when no matching help page exists" do
      expect(HelpPage.pretty_related_title("site_rules", help_pages)).to eq("Site Rules")
    end

    it "returns name.titleize for a matching page whose title is blank" do
      expect(HelpPage.pretty_related_title("tagging", help_pages)).to eq("Tagging")
    end
  end

  # -------------------------------------------------------------------------
  # .help_index — caching and cache invalidation
  # -------------------------------------------------------------------------
  describe ".help_index" do
    before { Cache.delete("help_index") }

    it "returns all help pages sorted by pretty_title" do
      b_page = create(:help_page, name: "beta_topic",  title: "Beta Topic")
      a_page = create(:help_page, name: "alpha_topic", title: "Alpha Topic")

      result = HelpPage.help_index
      expect(result.map(&:name)).to eq([a_page.name, b_page.name])
    end

    it "caches the result so a second call does not re-query" do
      create(:help_page)
      HelpPage.help_index
      expect(Cache.fetch("help_index")).not_to be_nil
    end

    it "includes a newly created help page after cache invalidation" do
      existing = create(:help_page)
      HelpPage.help_index # prime the cache

      new_page = create(:help_page) # after_save invalidates cache

      result = HelpPage.help_index
      expect(result.map(&:id)).to include(existing.id, new_page.id)
    end

    it "excludes a destroyed help page after cache invalidation" do
      page     = create(:help_page)
      survivor = create(:help_page)
      HelpPage.help_index # prime the cache

      page.destroy # after_destroy invalidates cache

      result = HelpPage.help_index
      expect(result.map(&:id)).not_to include(page.id)
      expect(result.map(&:id)).to include(survivor.id)
    end
  end
end
