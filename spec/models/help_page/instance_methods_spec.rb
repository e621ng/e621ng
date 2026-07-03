# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        HelpPage Instance Methods                            #
# --------------------------------------------------------------------------- #

RSpec.describe HelpPage do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #pretty_title
  # -------------------------------------------------------------------------
  describe "#pretty_title" do
    it "returns the title when title is present" do
      page = build(:help_page, title: "Uploading Images")
      expect(page.pretty_title).to eq("Uploading Images")
    end

    it "falls back to name.titleize when title is blank" do
      page = build(:help_page, name: "uploading_images", title: "")
      expect(page.pretty_title).to eq("Uploading Images")
    end

    it "falls back to name.titleize when title is nil" do
      page = build(:help_page, name: "site_rules", title: nil)
      expect(page.pretty_title).to eq("Site Rules")
    end
  end

  # -------------------------------------------------------------------------
  # #related_array
  # -------------------------------------------------------------------------
  describe "#related_array" do
    it "returns an empty array when related is blank" do
      page = build(:help_page, related: "")
      expect(page.related_array).to eq([])
    end

    it "returns a single-element array for one related name" do
      page = build(:help_page, related: "tagging")
      expect(page.related_array).to eq(["tagging"])
    end

    it "splits on commas and strips surrounding whitespace" do
      page = build(:help_page, related: "tagging, uploading , ratings")
      expect(page.related_array).to eq(%w[tagging uploading ratings])
    end
  end
end
