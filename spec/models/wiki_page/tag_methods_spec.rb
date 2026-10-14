# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          WikiPage Tag Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPage do
  include_context "as admin"
  include_context "with tag categories"

  # -------------------------------------------------------------------------
  # #category_id getter
  # -------------------------------------------------------------------------
  describe "#category_id" do
    it "returns nil when no associated tag exists" do
      page = create(:wiki_page)
      expect(page.category_id).to be_nil
    end

    it "returns the tag's category value when a tag is associated" do
      create(:tag, name: "tagged_category_page", category: artist_tag_category)
      page = create(:wiki_page, title: "tagged_category_page")
      # Reload to force has_one :tag to re-query
      page.reload
      expect(page.category_id).to eq(artist_tag_category)
    end

    it "reflects external tag category changes after a reload" do
      tag = create(:tag, name: "recategorized_page", category: artist_tag_category)
      page = create(:wiki_page, title: "recategorized_page")
      page.reload
      expect(page.category_id).to eq(artist_tag_category)

      tag.update!(category: species_tag_category)
      page.reload
      expect(page.category_id).to eq(species_tag_category)
    end
  end

  # -------------------------------------------------------------------------
  # Tag creation decoupling
  # -------------------------------------------------------------------------
  describe "tag creation" do
    it "never creates a Tag when a wiki page is created" do
      expect do
        create(:wiki_page, title: "plain_wiki_no_tag")
      end.not_to change(Tag, :count)
    end

    it "does not update an existing tag when the wiki page is saved" do
      tag = create(:tag, name: "existing_tag_wiki", category: artist_tag_category)
      page = create(:wiki_page, title: "existing_tag_wiki")
      page.update!(body: "updated body")
      expect(tag.reload.category).to eq(artist_tag_category)
    end
  end
end
