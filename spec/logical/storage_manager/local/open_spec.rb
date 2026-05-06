# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager::Local do
  let(:tmpdir) { Dir.mktmpdir }
  let(:manager) { described_class.new(base_dir: tmpdir) }

  after { FileUtils.remove_entry(tmpdir) }

  describe "#open" do
    let(:path) { File.join(tmpdir, "file.bin") }
    let(:content) { "binary\x00data" }

    before { File.binwrite(path, content) }

    it "returns a File object" do
      file = manager.open(path)
      expect(file).to be_a(File)
      file.close
    end

    it "opens the file in binary mode" do
      file = manager.open(path)
      expect(file.binmode?).to be(true)
      file.close
    end

    it "reads back the correct content" do
      file = manager.open(path)
      expect(file.read).to eq(content)
      file.close
    end

    context "when the file does not exist" do
      it "raises Errno::ENOENT" do
        expect { manager.open(File.join(tmpdir, "missing.bin")) }.to raise_error(Errno::ENOENT)
      end
    end
  end
end
