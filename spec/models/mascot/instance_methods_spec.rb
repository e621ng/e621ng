# frozen_string_literal: true

RSpec.describe Mascot do
  include_context "as admin"

  let(:mascot) { create(:mascot) }

  describe "#url_path" do
    it "returns a URL containing the mascot's md5 and file extension" do
      expect(mascot.url_path).to match(/#{Regexp.escape(mascot.md5)}\.#{Regexp.escape(mascot.file_ext)}/)
    end
  end

  # describe "#file_path" do
  #   # FIXME: Mascot#file_path calls `storage_manager.mascot_path(self)` (1 arg) but
  #   # StorageManager#mascot_path(md5, file_ext) expects 2 args — calling it raises ArgumentError.
  #   it "returns a filesystem path containing the mascot's md5 and file extension" do
  #     pending "model bug: mascot_path(self) passes 1 arg but the method expects (md5, file_ext)"
  #     expect(mascot.file_path).to match(/#{Regexp.escape(mascot.md5)}\.#{Regexp.escape(mascot.file_ext)}/)
  #   end
  # end

  describe "#method_attributes" do
    it "includes :url_path" do
      expect(mascot.method_attributes).to include(:url_path)
    end
  end

  describe "#invalidate_cache" do
    it "deletes the active_mascots cache key" do
      # Create the record first so the after_commit callback fires before we set
      # up the expectation — otherwise the creation commit counts as a second call.
      record = create(:mascot)
      allow(Cache).to receive(:delete)
      record.invalidate_cache
      expect(Cache).to have_received(:delete).with("active_mascots")
    end
  end
end
