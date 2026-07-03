# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         StaffWiki Factory                                   #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWiki do
  include_context "as member"

  describe "factory" do
    it "produces a valid staff wiki with build" do
      wiki = build(:staff_wiki)
      expect(wiki).to be_valid, wiki.errors.full_messages.join(", ")
    end

    it "produces a valid staff wiki with create" do
      wiki = create(:staff_wiki)
      expect(wiki).to be_persisted
    end
  end
end
