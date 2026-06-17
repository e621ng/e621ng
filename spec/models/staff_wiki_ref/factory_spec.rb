# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffWikiRef Factory                                #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWikiRef do
  include_context "as member"

  describe "factory" do
    it "produces a valid staff wiki ref with build" do
      ref = build(:staff_wiki_ref)
      expect(ref).to be_valid, ref.errors.full_messages.join(", ")
    end

    it "produces a valid staff wiki ref with create" do
      ref = create(:staff_wiki_ref)
      expect(ref).to be_persisted
    end
  end
end
