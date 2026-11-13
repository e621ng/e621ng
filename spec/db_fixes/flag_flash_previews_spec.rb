# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/fixes/145_flag_flash_previews")

RSpec.describe Fixes::FlagFlashPreviews do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }
  let(:storage) { StorageManager::Local.new(base_dir: dir, hierarchical: true) }

  before do
    allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage)
  end

  after { FileUtils.rm_rf(dir) }

  def run!
    expect { described_class.run }.to output.to_stdout
  end

  def add_previews(post, types = %i[preview_jpg preview_webp])
    types.each do |type|
      path = storage.file_path(post.md5, post.file_ext, type, protect: post.protect_file?)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)
    end
  end

  it "flags a flash post with both previews" do
    post = create(:post, file_ext: "swf")
    add_previews(post)

    run!

    expect(post.reload.has_flash_preview?).to be(true)
  end

  it "does not flag a flash post with only a jpg preview" do
    post = create(:post, file_ext: "swf")
    add_previews(post, %i[preview_jpg])

    run!

    expect(post.reload.has_flash_preview?).to be(false)
  end

  it "looks for the previews of deleted posts in the protected directory" do
    post = create(:post, file_ext: "swf", is_deleted: true)
    add_previews(post)

    run!

    expect(post.reload.has_flash_preview?).to be(true)
  end

  it "clears the flag when the previews are missing" do
    post = create(:post, file_ext: "swf", has_flash_preview: true)

    run!

    expect(post.reload.has_flash_preview?).to be(false)
  end

  it "leaves other flags alone" do
    post = create(:post, file_ext: "swf", hide_from_anonymous: true)
    add_previews(post)

    run!

    post.reload
    expect(post.has_flash_preview?).to be(true)
    expect(post.hide_from_anonymous?).to be(true)
  end

  it "reports no changes on a second run" do
    add_previews(create(:post, file_ext: "swf"))
    run!

    expect { described_class.run }.to output(/Flagged: 0, Cleared: 0/).to_stdout
  end
end
