# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     StaffWikiVersion Factory Sanity Checks                  #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWikiVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid staff_wiki_version with build" do
      expect(build(:staff_wiki_version)).to be_valid
    end

    it "produces a valid staff_wiki_version with create" do
      expect(create(:staff_wiki_version)).to be_persisted
    end

    it "creating a staff_wiki automatically produces a version" do
      wiki = create(:staff_wiki)
      expect(wiki.versions.count).to eq(1)
    end
  end
end
