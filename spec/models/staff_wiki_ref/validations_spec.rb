# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       StaffWikiRef Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWikiRef do
  # -------------------------------------------------------------------------
  # related_type — presence
  # -------------------------------------------------------------------------
  describe "related_type — presence" do
    include_context "as member"

    it "is invalid when related_type is blank" do
      ref = build(:staff_wiki_ref, related_type: "")
      expect(ref).not_to be_valid
      expect(ref.errors[:related_type]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # related_type — inclusion
  # -------------------------------------------------------------------------
  describe "related_type — inclusion" do
    include_context "as member"

    it "is invalid with a type not in ALLOWED_TYPES" do
      ref = build(:staff_wiki_ref, related_type: "Post")
      expect(ref).not_to be_valid
      expect(ref.errors[:related_type]).to be_present
    end

    it "is valid with each allowed type" do
      expect([
        build(:staff_wiki_ref, related: create(:user)),
        build(:staff_wiki_ref, related: create(:artist)),
        build(:staff_wiki_ref, related: create(:staff_wiki)),
      ]).to all(be_valid)
    end
  end

  # -------------------------------------------------------------------------
  # related_id — uniqueness
  # -------------------------------------------------------------------------
  describe "related_id — uniqueness" do
    include_context "as member"

    it "is invalid when the same target is referenced twice on one wiki" do
      existing = create(:staff_wiki_ref)
      dup = build(:staff_wiki_ref, staff_wiki: existing.staff_wiki, related: existing.related)
      expect(dup).not_to be_valid
      expect(dup.errors[:related_id]).to be_present
    end

    it "allows the same target on a different wiki" do
      existing = create(:staff_wiki_ref)
      other = build(:staff_wiki_ref, staff_wiki: create(:staff_wiki), related: existing.related)
      expect(other).to be_valid
    end
  end
end
