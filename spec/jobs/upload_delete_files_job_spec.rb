# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadDeleteFilesJob do
  describe "#perform" do
    it "delegates to UploadService::Utils.delete_file" do
      allow(UploadService::Utils).to receive(:delete_file)
      described_class.perform_now("abc123", "jpg", nil)
      expect(UploadService::Utils).to have_received(:delete_file).with("abc123", "jpg", nil)
    end
  end
end
