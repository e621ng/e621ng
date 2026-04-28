# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Tag::NameMethods                                  #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"
  include_context "with tag categories"

  describe ".normalize_name" do
    it "downcases uppercase letters" do
      expect(Tag.normalize_name("UPPER_CASE")).to eq("upper_case")
    end

    it "strips leading and trailing whitespace" do
      expect(Tag.normalize_name("  spaced  ")).to eq("spaced")
    end

    it "converts spaces to underscores" do
      expect(Tag.normalize_name("tag with spaces")).to eq("tag_with_spaces")
    end

    it "applies NFC unicode normalization" do
      # "é" as decomposed (e + combining acute accent) → composed form
      decomposed = "e\u0301"
      composed   = "\u00E9"
      expect(Tag.normalize_name(decomposed)).to eq(Tag.normalize_name(composed))
    end

    it "returns an already-normalized name unchanged" do
      expect(Tag.normalize_name("already_normalized")).to eq("already_normalized")
    end
  end

  describe ".find_by_normalized_name" do
    it "returns the tag when found via unnormalized name" do
      tag = create(:tag, name: "find_me")
      # NOTE: Tag.find_by_normalized_name is a custom method, not a dynamic finder
      expect(Tag.find_by_normalized_name("FIND_ME")).to eq(tag) # rubocop:disable Rails/DynamicFindBy
    end

    it "returns nil when no matching tag exists" do
      # NOTE: Tag.find_by_normalized_name is a custom method, not a dynamic finder
      expect(Tag.find_by_normalized_name("nonexistent_tag")).to be_nil # rubocop:disable Rails/DynamicFindBy
    end
  end

  describe ".find_by_name_list" do
    it "returns tag objects for existing names" do
      tag = create(:tag, name: "existing_tag")
      # NOTE: Tag.find_by_name_list is a custom method, not a dynamic finder
      result = Tag.find_by_name_list(["existing_tag"]) # rubocop:disable Rails/DynamicFindBy
      expect(result["existing_tag"]).to eq(tag)
    end

    it "returns nil for names that do not exist" do
      # NOTE: Tag.find_by_name_list is a custom method, not a dynamic finder
      result = Tag.find_by_name_list(["nonexistent_ghost"]) # rubocop:disable Rails/DynamicFindBy
      expect(result["nonexistent_ghost"]).to be_nil
    end

    it "handles a mixed list of existing and missing names" do
      tag = create(:tag, name: "present_tag")
      # NOTE: Tag.find_by_name_list is a custom method, not a dynamic finder
      result = Tag.find_by_name_list(%w[present_tag absent_tag]) # rubocop:disable Rails/DynamicFindBy
      expect(result["present_tag"]).to eq(tag)
      expect(result["absent_tag"]).to be_nil
    end

    it "normalizes keys in the returned hash" do
      tag = create(:tag, name: "normalized_key")
      # NOTE: Tag.find_by_name_list is a custom method, not a dynamic finder
      result = Tag.find_by_name_list(["NORMALIZED_KEY"]) # rubocop:disable Rails/DynamicFindBy
      expect(result["normalized_key"]).to eq(tag)
    end
  end

  describe ".find_or_create_by_name" do
    it "returns an existing tag without creating a duplicate" do
      tag = create(:tag, name: "already_exists")
      expect { Tag.find_or_create_by_name("already_exists") }.not_to change(Tag, :count)
      expect(Tag.find_or_create_by_name("already_exists")).to eq(tag)
    end

    it "creates and returns a new tag when it does not exist" do
      expect { Tag.find_or_create_by_name("brand_new_tag") }.to change(Tag, :count).by(1)
      # NOTE: Tag.find_by_name is a custom method, not a dynamic finder
      expect(Tag.find_by_name("brand_new_tag")).to be_present # rubocop:disable Rails/DynamicFindBy
    end

    it "normalizes the name before looking up or creating" do
      tag = create(:tag, name: "normalized_lookup")
      expect(Tag.find_or_create_by_name("NORMALIZED_LOOKUP")).to eq(tag)
    end

    it "applies a category prefix when creating a new tag" do
      tag = Tag.find_or_create_by_name("director:new_artist_tag")
      expect(tag.name).to eq("new_artist_tag")
      expect(tag.category).to eq(artist_tag_category)
    end

    context "when the tag exists and a category prefix is given" do
      it "updates the category when the creator can edit it implicitly" do
        janitor = create(:janitor_user)
        tag = create(:tag, name: "implicit_change_tag", category: general_tag_category)
        Tag.find_or_create_by_name("director:implicit_change_tag", creator: janitor)
        expect(tag.reload.category).to eq(artist_tag_category)
      end

      it "does not change the category when the creator cannot edit it implicitly" do
        member = create(:user)
        tag = create(:tag, name: "no_implicit_change", category: general_tag_category)
        Tag.find_or_create_by_name("director:no_implicit_change", creator: member)
        expect(tag.reload.category).to eq(general_tag_category)
      end
    end
  end

  describe ".find_or_create_by_name_list" do
    it "creates only tags that do not yet exist" do
      create(:tag, name: "list_existing")
      expect do
        Tag.find_or_create_by_name_list(%w[list_existing list_new_one])
      end.to change(Tag, :count).by(1)
    end

    it "returns both existing and newly created tags" do
      create(:tag, name: "list_present")
      result = Tag.find_or_create_by_name_list(%w[list_present list_absent])
      names = result.map(&:name)
      expect(names).to include("list_present", "list_absent")
    end

    it "applies category prefixes to new tags" do
      Tag.find_or_create_by_name_list(["director:new_list_artist"])
      # NOTE: Tag.find_by_name is a custom method, not a dynamic finder
      tag = Tag.find_by_name("new_list_artist") # rubocop:disable Rails/DynamicFindBy
      expect(tag).to be_present
      expect(tag.category).to eq(artist_tag_category)
    end
  end
end
