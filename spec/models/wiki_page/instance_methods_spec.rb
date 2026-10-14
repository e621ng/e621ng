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
    include_context "with tag categories"

    it "returns pretty_title without a prefix when no tag exists" do
      page = build(:wiki_page, title: "some_page")
      expect(page.pretty_title_with_category).to eq("some page")
    end

    it "returns pretty_title without a prefix when the tag is general" do
      create(:tag, name: "some_page", category: general_tag_category)
      page = create(:wiki_page, title: "some_page").reload
      expect(page.pretty_title_with_category).to eq("some page")
    end

    it "prepends the capitalized category name for an artist tag" do
      create(:tag, name: "my_tag", category: artist_tag_category)
      page = create(:wiki_page, title: "my_tag").reload
      expect(page.pretty_title_with_category).to eq("#{TagCategory::REVERSE_MAPPING[artist_tag_category].capitalize}: my tag")
    end

    it "prepends the correct category name for a species tag" do
      create(:tag, name: "my_species", category: species_tag_category)
      page = create(:wiki_page, title: "my_species").reload
      expect(page.pretty_title_with_category).to eq("Species: my species")
    end
  end
end
