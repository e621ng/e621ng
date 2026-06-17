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
end
