# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        PostSet Normalizations                               #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  # -------------------------------------------------------------------------
  # normalize_shortname (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_shortname" do
    it "downcases the shortname when it is changed" do
      set = build(:post_set, shortname: "My_Set_Name")
      set.valid?
      expect(set.shortname).to eq("my_set_name")
    end

    it "downcases the shortname when creating a new record" do
      set = create(:post_set, shortname: "Upper_Case")
      expect(set.shortname).to eq("upper_case")
    end

    it "does not alter the shortname when shortname is unchanged on update" do
      set = create(:post_set, shortname: "already_lower")
      original_shortname = set.shortname
      set.name = "New Name For Set"
      set.valid?
      expect(set.shortname).to eq(original_shortname)
    end
  end
end
