# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::PostReplacements, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }
  let(:storage_dir) { Dir.mktmpdir }
  let(:storage) { StorageManager::Local.new(base_dir: storage_dir, hierarchical: true) }

  before { allow(Danbooru.config.custom_configuration).to receive(:storage_manager).and_return(storage) }

  after { FileUtils.rm_rf([dir, storage_dir]) }

  it "imports approved replacements and the original backup with derived numbering and placeholder files" do
    post = create(:post)
    original = create(:original_post_replacement, post: post, image_width: 640, image_height: 480)
    first = create(:approved_post_replacement, post: post)
    second = create(:approved_post_replacement, post: post, file_ext: "png")
    create(:pending_post_replacement, post: post) # not exported
    %w[posts post_replacements].each { |name| write_export(name, dir) }
    PostReplacement.delete_all

    result = nil
    expect { result = described_class.new(dir: dir).call }.to output(/replacements: 3 inserted/).to_stdout

    expect(result).to eq(replacements: 3)
    imported = PostReplacement.where(post_id: post.id).order(:sequence_number)
    expect(imported.map(&:id)).to eq([original.id, first.id, second.id])
    expect(imported.map(&:sequence_number)).to eq([0, 1, 2])
    expect(imported.map(&:storage_id)).to all(match(/\A\h{32}\z/))
    imported.each do |replacement|
      expect(File.exist?(storage.replacement_path(replacement, replacement.file_ext, :original))).to be(true)
      expect(File.exist?(storage.replacement_path(replacement, replacement.file_ext, :preview))).to be(true)
    end
    expect(User.exists?(first.approver_id)).to be(true)

    expect { expect(described_class.new(dir: dir).call).to eq(replacements: 0) }.to output.to_stdout
  end
end
