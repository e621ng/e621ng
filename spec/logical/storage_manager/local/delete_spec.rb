# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager::Local do
  let(:tmpdir) { Dir.mktmpdir }
  let(:manager) { described_class.new(base_dir: tmpdir) }

  after { FileUtils.remove_entry(tmpdir) }

  describe "#delete" do
    context "when the file exists" do
      it "removes the file" do
        path = File.join(tmpdir, "target.jpg")
        File.write(path, "content")
        manager.delete(path)
        expect(File.exist?(path)).to be(false)
      end
    end

    context "when the file does not exist" do
      it "does not raise an error" do
        path = File.join(tmpdir, "nonexistent.jpg")
        expect { manager.delete(path) }.not_to raise_error
      end
    end
  end
end
