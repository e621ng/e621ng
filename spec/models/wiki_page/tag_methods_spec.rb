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
  end

  # -------------------------------------------------------------------------
  # #category_id=
  # -------------------------------------------------------------------------
  describe "#category_id=" do
    it "sets the category_id instance variable to the integer value of the input" do
      page = build(:wiki_page)
      page.category_id = artist_tag_category.to_s
      expect(page.category_id).to eq(artist_tag_category)
    end

    it "does not set category_id when the value is blank" do
      page = build(:wiki_page)
      page.category_id = ""
      expect(page.category_id).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  # #category_is_locked getter
  # -------------------------------------------------------------------------
  describe "#category_is_locked" do
    it "returns false when no associated tag exists" do
      page = create(:wiki_page)
      expect(page.category_is_locked).to be false
    end

    it "returns the tag's is_locked value when a tag is associated" do
      create(:tag, name: "locked_category_page", is_locked: true)
      page = create(:wiki_page, title: "locked_category_page")
      page.reload
      expect(page.category_is_locked).to be true
    end
  end

  # -------------------------------------------------------------------------
  # create_tag (before_create)
  # -------------------------------------------------------------------------
  describe "create_tag" do
    it "creates a Tag record when category_id is set during creation" do
      expect do
        page = build(:wiki_page, title: "new_artist_wiki")
        page.category_id = artist_tag_category
        page.save!
      end.to change(Tag, :count).by(1)
      expect(Tag.find_by(name: "new_artist_wiki")).to be_present
    end

    it "does not create a Tag when category_id is not set" do
      expect do
        create(:wiki_page, title: "plain_wiki_no_tag")
      end.not_to change(Tag, :count)
    end

    it "does not create a duplicate Tag when a tag with the same name already exists" do
      create(:tag, name: "existing_tag_wiki")
      expect do
        page = build(:wiki_page, title: "existing_tag_wiki")
        page.category_id = artist_tag_category
        page.save!
      end.not_to change(Tag, :count)
    end

    it "stores the correct category on the newly created tag" do
      page = build(:wiki_page, title: "species_wiki")
      page.category_id = species_tag_category
      page.save!
      expect(Tag.find_by(name: "species_wiki").category).to eq(species_tag_category)
    end

    it "adds a category_id error and aborts when the user cannot create the tag category" do
      # Members cannot create admin-only categories (meta=7, invalid=6, lore=8).
      # The Tag model's user_can_change_category? validation fires on create
      # when category changes from the default, causing Tag#save to fail,
      # which triggers tag_error on the wiki page.
      CurrentUser.user = create(:user)
      page = build(:wiki_page, title: "member_meta_wiki")
      page.category_id = meta_tag_category
      result = page.save
      expect(result).to be false
      expect(page.errors[:category_id]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # update_tag (before_save)
  # -------------------------------------------------------------------------
  describe "update_tag" do
    let!(:wiki_with_tag) do
      p = build(:wiki_page, title: "updateable_tag_wiki")
      p.category_id = artist_tag_category
      p.save!
      p
    end

    it "updates the tag's category when category_id changes" do
      wiki_with_tag.category_id = species_tag_category
      wiki_with_tag.save!
      expect(Tag.find_by(name: "updateable_tag_wiki").category).to eq(species_tag_category)
    end

    it "updates the tag's is_locked when category_is_locked changes" do
      wiki_with_tag.category_is_locked = true
      wiki_with_tag.save!
      expect(Tag.find_by(name: "updateable_tag_wiki").is_locked).to be true
    end

    it "is a no-op when neither category_id nor category_is_locked has been assigned" do
      original_category = Tag.find_by(name: "updateable_tag_wiki").category
      wiki_with_tag.body = "just a body update"
      wiki_with_tag.save!
      expect(Tag.find_by(name: "updateable_tag_wiki").category).to eq(original_category)
    end

    it "adds a category_id error and aborts when the user cannot change the category" do
      # Create a wiki page with meta category (7) as admin so the tag is admin-only.
      # A member's attempt to change the category should be blocked because
      # tag.category_editable_by? returns false for an admin-only category.
      meta_page = build(:wiki_page, title: "meta_tag_wiki")
      meta_page.category_id = meta_tag_category
      meta_page.save!

      CurrentUser.user = create(:user)
      meta_page.category_id = artist_tag_category
      result = meta_page.save
      expect(result).to be false
      expect(meta_page.errors[:category_id]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # #category_editable_by?
  # -------------------------------------------------------------------------
  describe "#category_editable_by?" do
    it "returns true when no tag is associated (tag is nil)" do
      page = create(:wiki_page)
      member = create(:user)
      expect(page.category_editable_by?(member)).to be true
    end

    it "delegates to tag.category_editable_by? when a tag is associated" do
      page = build(:wiki_page, title: "delegate_cat_wiki")
      page.category_id = artist_tag_category
      page.save!
      page.reload
      expect(page.category_editable_by?(CurrentUser.user)).to eq(page.tag.category_editable_by?(CurrentUser.user))
    end

    it "returns false for a member when the existing tag is in an admin-only category" do
      meta_page = build(:wiki_page, title: "meta_editable_wiki")
      meta_page.category_id = meta_tag_category
      meta_page.save!
      meta_page.reload
      member = create(:user)
      expect(meta_page.category_editable_by?(member)).to be false
    end
  end
end
