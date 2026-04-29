# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        WikiPage Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #pretty_title
  # -------------------------------------------------------------------------
  describe "#pretty_title" do
    it "returns the title with underscores replaced by spaces" do
      page = build(:wiki_page, title: "my_wiki_page")
      expect(page.pretty_title).to eq("my wiki page")
    end

    it "returns an empty string when title is nil" do
      page = build(:wiki_page)
      page.title = nil
      expect(page.pretty_title).to eq("")
    end
  end

  # -------------------------------------------------------------------------
  # #pretty_title_with_category
  # -------------------------------------------------------------------------
  describe "#pretty_title_with_category" do
    it "returns pretty_title without a prefix when category_id is nil" do
      page = build(:wiki_page, title: "some_page")
      expect(page.pretty_title_with_category).to eq("some page")
    end

    it "returns pretty_title without a prefix when category_id is 0 (general)" do
      page = build(:wiki_page, title: "some_page")
      page.category_id = 0 # general
      expect(page.pretty_title_with_category).to eq("some page")
    end

    it "prepends the capitalized category name for category 1" do
      page = build(:wiki_page, title: "my_tag")
      page.category_id = 1
      expect(page.pretty_title_with_category).to eq("#{TagCategory::REVERSE_MAPPING[1].capitalize}: my tag")
    end

    it "prepends the correct category name for species" do
      page = build(:wiki_page, title: "my_species")
      page.category_id = 5 # species
      expect(page.pretty_title_with_category).to eq("Species: my species")
    end
  end
end
