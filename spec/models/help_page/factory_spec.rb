# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            HelpPage Factory                                 #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # Factory sanity checks
  # -------------------------------------------------------------------------
  describe "factory" do
    it "produces a valid record with build" do
      page = build(:help_page)
      expect(page).to be_valid, page.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      expect(create(:help_page)).to be_persisted
    end
  end
end
