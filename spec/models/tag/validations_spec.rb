# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              Tag Validations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Tag do
  include_context "as admin"
  include_context "with tag categories"

  describe "validations" do
    # -------------------------------------------------------------------------
    # name — length (always enforced)
    # -------------------------------------------------------------------------
    describe "name length" do
      it "is invalid with an empty name" do
        tag = build(:tag, name: "")
        expect(tag).not_to be_valid
        expect(tag.errors[:name]).to be_present
      end

      it "is invalid when name exceeds 100 characters" do
        tag = build(:tag, name: "a" * 101)
        expect(tag).not_to be_valid
        expect(tag.errors[:name]).to be_present
      end

      it "is valid at exactly 100 characters" do
        tag = build(:tag, name: "a" * 100)
        expect(tag).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # name — uniqueness (on: :create only)
    # -------------------------------------------------------------------------
    describe "name uniqueness" do
      it "is invalid when a tag with the same name already exists" do
        create(:tag, name: "duplicate_tag")
        duplicate = build(:tag, name: "duplicate_tag")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to be_present
      end

      it "does not re-enforce uniqueness on update" do
        tag = create(:tag, name: "original_name")
        tag.is_locked = true
        expect(tag).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # name — tag_name format (on: :create, smoke test)
    # -------------------------------------------------------------------------
    describe "name format (on create)" do
      it "is invalid for a name starting with a dash" do
        tag = build(:tag, name: "-bad_name")
        expect(tag).not_to be_valid
        expect(tag.errors[:name]).to be_present
      end

      it "does not re-validate name format on update" do
        tag = create(:tag, name: "valid_name")
        # Directly corrupt the name in the DB to bypass creation validation,
        # then confirm updating another field is valid.
        tag.update_columns(name: "-corrupt_name")
        tag.reload
        tag.is_locked = true
        expect(tag).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # category — inclusion
    # -------------------------------------------------------------------------
    describe "category inclusion" do
      it "is valid for each category ID 0–8" do
        TagCategory::CATEGORY_IDS.each do |cat_id|
          name = "tag_cat_#{cat_id}_#{SecureRandom.hex(4)}"
          # Lore (8) requires name to end with _(lore)
          name = "lore_tag_(lore)" if cat_id == 8
          tag = build(:tag, name: name, category: cat_id)
          expect(tag).to be_valid, "expected category #{cat_id} to be valid: #{tag.errors.full_messages.join(', ')}"
        end
      end

      it "is invalid with nil category" do
        tag = build(:tag, category: nil)
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to be_present
      end

      it "is invalid with a category below range" do
        tag = build(:tag, category: -1)
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to be_present
      end

      it "is invalid with a category above range" do
        tag = build(:tag, category: 9)
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to be_present
      end

      it "is invalid with a non-numeric category string" do
        tag = build(:tag, category: "artist")
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to be_present
      end
    end

    # -------------------------------------------------------------------------
    # user_can_create_tag? (on: :create)
    # -------------------------------------------------------------------------
    describe "user_can_create_tag? (on create)" do
      it "is invalid when a non-admin tries to create a lore-named tag", skip: "This test is skipped on this fork" do
        CurrentUser.user = create(:user)
        tag = build(:tag, name: "my_lore_tag_(lore)", category: lore_tag_category)
        expect(tag).not_to be_valid
        expect(tag.errors[:base]).to include("Can not create lore tags unless admin")
        expect(tag.errors[:name]).to be_present
      end

      it "is valid when an admin creates a lore-named tag", skip: "This test is skipped on this fork" do
        tag = build(:tag, name: "admin_lore_(lore)", category: lore_tag_category)
        expect(tag).to be_valid
      end

      it "is valid when a non-admin creates a non-lore tag" do
        CurrentUser.user = create(:user)
        tag = build(:tag, name: "normal_tag")
        expect(tag).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # user_can_change_category? (if: :category_changed?)
    # -------------------------------------------------------------------------
    describe "user_can_change_category? (on category change)" do
      let(:tag) { create(:tag, name: "changeable_tag") }

      it "is invalid when a non-admin changes category to invalid (6)" do
        CurrentUser.user = create(:janitor_user)
        tag.category = invalid_tag_category
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to include("can only used by admins")
      end

      it "is invalid when a non-admin changes category to meta (7)" do
        CurrentUser.user = create(:janitor_user)
        tag.category = meta_tag_category
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to include("can only used by admins")
      end

      it "is invalid when a non-admin changes category to lore (8)" do
        CurrentUser.user = create(:janitor_user)
        tag.category = lore_tag_category
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to include("can only used by admins")
      end

      it "is valid when an admin changes category to an admin-only category" do
        tag.category = meta_tag_category
        expect(tag).to be_valid
      end

      it "is invalid when applying lore category to a tag name not ending with _(lore)" do
        tag.category = lore_tag_category
        expect(tag).not_to be_valid
        expect(tag.errors[:category]).to include("can only be applied to tags that end with '_(lore)'")
      end

      it "is valid when applying lore category to a tag name ending with _(lore)" do
        lore_tag = create(:tag, name: "proper_(lore)")
        lore_tag.category = lore_tag_category
        expect(lore_tag).to be_valid
      end
    end
  end
end
