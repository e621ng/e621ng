# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         HelpPage Normalizations                             #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # normalize name (applied via ActiveRecord normalizes before validation)
  # -------------------------------------------------------------------------
  describe "normalize name" do
    it "downcases the name" do
      page = create(:help_page, name: "MyHelpPage")
      expect(page.name).to eq("myhelppage")
    end

    it "strips leading and trailing whitespace from the name" do
      page = create(:help_page, name: "  trimmed  ")
      expect(page.name).to eq("trimmed")
    end

    it "converts spaces to underscores in the name" do
      page = create(:help_page, name: "a help topic")
      expect(page.name).to eq("a_help_topic")
    end

    it "applies all normalizations together" do
      page = create(:help_page, name: "  My Help Page  ")
      expect(page.name).to eq("my_help_page")
    end
  end
end
