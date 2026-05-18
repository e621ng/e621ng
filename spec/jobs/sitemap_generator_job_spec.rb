# frozen_string_literal: true

require "rails_helper"

RSpec.describe SitemapGeneratorJob do
  describe "#perform" do
    it "generates the sitemap without error" do
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
