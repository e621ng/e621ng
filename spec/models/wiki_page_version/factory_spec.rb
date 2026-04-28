# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   WikiPageVersion Factory Sanity Checks                     #
# --------------------------------------------------------------------------- #

RSpec.describe WikiPageVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid wiki_page_version with build" do
      expect(build(:wiki_page_version)).to be_valid
    end

    it "produces a valid wiki_page_version with create" do
      expect(create(:wiki_page_version)).to be_persisted
    end

    it "creating a wiki_page automatically produces a version" do
      wiki_page = create(:wiki_page)
      expect(wiki_page.versions.count).to eq(1)
    end
  end
end
