# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Tag::CategoryMethods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"
  include_context "with tag categories"

  # -------------------------------------------------------------------------
  # CategoryMapping
  # -------------------------------------------------------------------------
  describe "CategoryMapping" do
    subject(:mapping) { Tag.categories }

    it "exposes a method for each category returning the correct ID" do
      TagCategory::REVERSE_MAPPING.each do |id, name|
        expect(mapping.public_send(name)).to eq(id),
                                             "expected Tag.categories.#{name} to return #{id}"
      end
    end

    describe "#value_for" do
      it "returns the category ID for a known category string" do
        expect(mapping.value_for("director")).to eq(artist_tag_category)
      end

      it "returns 0 (general) for an unknown string" do
        expect(mapping.value_for("does_not_exist")).to eq(0)
      end

      it "is case-insensitive" do
        expect(mapping.value_for("DIRECTOR")).to eq(artist_tag_category)
      end
    end

    describe "#regexp" do
      it "matches all known category name aliases" do
        TagCategory::MAPPING.each_key do |alias_name|
          expect(alias_name).to match(mapping.regexp),
                                "expected regexp to match category alias '#{alias_name}'"
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # .category_for_value
  # -------------------------------------------------------------------------
  describe ".category_for_value" do
    it "returns the capitalized category name for each valid ID" do
      TagCategory::REVERSE_MAPPING.each do |id, name|
        expect(Tag.category_for_value(id)).to eq(name.capitalize)
      end
    end

    it "returns 'Unknown category' for an unrecognised ID" do
      expect(Tag.category_for_value(999)).to eq("Unknown category")
    end
  end

  # -------------------------------------------------------------------------
  # #category_name
  # -------------------------------------------------------------------------
  describe "#category_name" do
    it "returns the lowercase category name for each category" do
      TagCategory::REVERSE_MAPPING.each do |id, name|
        tag_name = id == 8 ? "cat_name_test_(lore)" : "cat_name_test_#{id}"
        tag = create(:tag, name: tag_name, category: id)
        expect(tag.category_name).to eq(name)
      end
    end
  end

  # -------------------------------------------------------------------------
  # #category_editable_by_implicit?
  # -------------------------------------------------------------------------
  describe "#category_editable_by_implicit?" do
    let(:tag) { create(:tag, name: "implicit_test_tag") }

    it "returns false for a regular member" do
      member = create(:user)
      expect(tag.category_editable_by_implicit?(member)).to be false
    end

    it "returns false when the tag is locked" do
      janitor = create(:janitor_user)
      locked_tag = create(:locked_tag)
      expect(locked_tag.category_editable_by_implicit?(janitor)).to be false
    end

    it "returns false when post_count is at or above the cutoff" do
      janitor = create(:janitor_user)
      heavy_tag = create(:high_post_count_tag)
      expect(heavy_tag.category_editable_by_implicit?(janitor)).to be false
    end

    it "returns true for a janitor on an unlocked tag below the cutoff" do
      janitor = create(:janitor_user)
      expect(tag.category_editable_by_implicit?(janitor)).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #category_editable_by?
  # -------------------------------------------------------------------------
  describe "#category_editable_by?" do
    let(:tag) { create(:tag, name: "explicit_test_tag") }

    it "returns true for an admin regardless of lock status" do
      admin = create(:admin_user)
      locked_tag = create(:locked_tag)
      expect(locked_tag.category_editable_by?(admin)).to be true
    end

    it "returns false when the tag is locked and the user is not admin" do
      member = create(:user)
      locked_tag = create(:locked_tag)
      expect(locked_tag.category_editable_by?(member)).to be false
    end

    it "returns false for a non-admin when the tag has an admin-only category" do
      member = create(:user)
      # Set category directly to bypass validation (category change guard)
      tag.update_columns(category: meta_tag_category)
      tag.reload
      expect(tag.category_editable_by?(member)).to be false
    end

    it "returns true for a non-admin on a non-admin-only category below the cutoff" do
      member = create(:user)
      expect(tag.category_editable_by?(member)).to be true
    end

    it "returns false for a non-admin when post_count is at or above the cutoff" do
      member = create(:user)
      heavy_tag = create(:high_post_count_tag)
      expect(heavy_tag.category_editable_by?(member)).to be false
    end
  end
end
