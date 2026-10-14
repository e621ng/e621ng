# frozen_string_literal: true

require "rails_helper"

RSpec.describe AsnRangesUpdateJob do
  describe "#perform" do
    it "runs the importer" do
      allow(AsnRangeImporter).to receive(:import!)
      described_class.new.perform
      expect(AsnRangeImporter).to have_received(:import!)
    end
  end
end
