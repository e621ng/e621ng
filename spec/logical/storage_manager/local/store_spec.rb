# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager::Local do
  let(:tmpdir) { Dir.mktmpdir }
  let(:manager) { described_class.new(base_dir: tmpdir) }
  let(:fixture_path) { file_fixture("sample.jpg") }
  let(:dest) { File.join(tmpdir, "sample.jpg") }

  after { FileUtils.remove_entry(tmpdir) }

  describe "#store" do
    it "writes the io content to the destination path" do
      File.open(fixture_path) { |io| manager.store(io, dest) }
      expect(File.read(dest)).to eq(File.read(fixture_path))
    end

    it "creates parent directories when they do not exist" do
      nested_dest = File.join(tmpdir, "a", "b", "c", "sample.jpg")
      File.open(fixture_path) { |io| manager.store(io, nested_dest) }
      expect(File.exist?(nested_dest)).to be(true)
    end

    it "sets file permissions to 0644" do
      File.open(fixture_path) { |io| manager.store(io, dest) }
      expect(File.stat(dest).mode & 0o777).to eq(0o644)
    end

    it "leaves no .tmp files in the destination directory after success" do
      File.open(fixture_path) { |io| manager.store(io, dest) }
      tmp_files = Dir.glob("#{tmpdir}/*.tmp")
      expect(tmp_files).to be_empty
    end

    it "overwrites an existing file at the destination" do
      File.write(dest, "old content")
      File.open(fixture_path) { |io| manager.store(io, dest) }
      expect(File.read(dest)).to eq(File.read(fixture_path))
    end

    context "when the reported io size does not match bytes copied" do
      it "raises StorageManager::Error" do
        io = File.open(fixture_path)
        allow(io).to receive(:size).and_return(0)
        expect { manager.store(io, dest) }.to raise_error(StorageManager::Error, /store failed/)
      ensure
        io&.close
      end
    end

    context "when an error occurs mid-store" do
      it "cleans up the temp file" do
        io = File.open(fixture_path)
        allow(File).to receive(:rename).and_raise(StandardError, "rename failed")
        expect { manager.store(io, dest) }.to raise_error(StorageManager::Error)
        tmp_files = Dir.glob("#{tmpdir}/*.tmp")
        expect(tmp_files).to be_empty
      ensure
        io&.close
      end
    end
  end
end
