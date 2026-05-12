# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                   Sources::Alternates::Webtoons                             #
# --------------------------------------------------------------------------- #

RSpec.describe Sources::Alternates::Webtoons do
  def transform(url)
    described_class.new(url).original_url
  end

  # -------------------------------------------------------------------------
  # #match?
  # -------------------------------------------------------------------------
  describe "#match?" do
    it "matches webtoons.com" do
      expect(described_class.new("https://www.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314").match?).to be true
    end

    it "matches m.webtoons.com" do
      expect(described_class.new("https://m.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314").match?).to be true
    end

    it "does not match unrelated domains" do
      expect(described_class.new("https://example.com/foo").match?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #force_https?
  # -------------------------------------------------------------------------
  describe "#force_https?" do
    it "upgrades http:// webtoons.com URLs to https://" do
      expect(described_class.new("http://www.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314").url).to start_with("https://")
    end
  end

  # -------------------------------------------------------------------------
  # #original_url — mobile to desktop
  # -------------------------------------------------------------------------
  describe "#original_url — mobile to desktop" do
    it "converts m.webtoons.com to www.webtoons.com" do
      expect(transform("https://m.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314")).to \
        eq("https://www.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314")
    end

    it "does not alter already-desktop URLs" do
      url = "https://www.webtoons.com/en/canvas/forestdale/forestdale-314-missed-birthday/viewer?title_no=856922&episode_no=314"
      expect(transform(url)).to eq(url)
    end
  end
end
