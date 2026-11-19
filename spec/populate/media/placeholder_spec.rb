# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::Media::Placeholder do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }
  let(:storage) { StorageManager::Local.new(base_dir: dir, hierarchical: true) }

  before { allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage) }

  after { FileUtils.rm_rf(dir) }

  def exists?(post, type)
    File.exist?(storage.post_file_path(post, type))
  end

  it "writes originals, previews and samples where the post would have them" do
    small = create(:post, file_ext: "jpg", image_width: 640, image_height: 480)
    large = create(:post, file_ext: "png", image_width: 2000, image_height: 2000)
    flash = create(:post, file_ext: "swf", image_width: 640, image_height: 480)
    gone = create(:deleted_post, file_ext: "jpg", image_width: 640, image_height: 480)

    result = nil
    expect { result = described_class.new(post_ids: [small.id, large.id, flash.id, gone.id], threads: 2).call }.to output(%r{4/4}).to_stdout

    expect(result).to eq(generated: 4, failed: 0)
    expect(exists?(small, :original)).to be(true)
    expect(exists?(small, :preview_jpg)).to be(true)
    expect(exists?(small, :preview_webp)).to be(true)
    expect(exists?(small, :sample_jpg)).to be(false)
    expect(exists?(large, :sample_jpg)).to be(true)
    expect(exists?(large, :sample_webp)).to be(true)
    expect(exists?(flash, :original)).to be(false)
    expect(exists?(gone, :original)).to be(true) # on the protected path
    expect(storage.post_file_path(gone, :original)).to include(Danbooru.config.protected_path_prefix)
    expect(VipsCommand.dimensions(storage.post_file_path(small, :preview_jpg))).to eq([341, 256]) # short side scaled to 256

    expect { expect(described_class.new(post_ids: [small.id]).call).to eq(generated: 0, failed: 0) }.to output(/for 0 posts/).to_stdout
  end

  it "makes a short clip for video posts" do
    video = create(:post, file_ext: "webm", image_width: 320, image_height: 240)

    expect { described_class.new(post_ids: [video.id], threads: 1).call }.to output(/0 failed/).to_stdout

    expect(exists?(video, :original)).to be(true)
    expect(exists?(video, :preview_jpg)).to be(true)
    expect(exists?(video, :sample_jpg)).to be(true)
  end
end
