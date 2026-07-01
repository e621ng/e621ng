# frozen_string_literal: true

require "rails_helper"

RSpec.describe DbExport do
  describe "validations" do
    it "requires a name" do
      expect(described_class.new(name: nil)).not_to be_valid
    end

    it "requires a unique name" do
      described_class.create!(name: "posts", file_size: 0)
      expect(described_class.new(name: "posts", file_size: 0)).not_to be_valid
    end
  end

  describe "#file_name" do
    it "appends the gzipped csv extension to the name" do
      expect(described_class.new(name: "posts").file_name).to eq("posts.csv.gz")
    end
  end

  describe "#url" do
    it "delegates to the storage manager with the file name" do
      export = described_class.new(name: "posts")
      # config builds a new storage manager per call, so pin one to stub against.
      storage = Danbooru.config.storage_manager
      allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
      allow(storage).to receive(:db_export_url).with("posts.csv.gz").and_return("https://example.com/posts.csv.gz")
      expect(export.url).to eq("https://example.com/posts.csv.gz")
    end
  end
end
