# frozen_string_literal: true

require "rails_helper"

RSpec.describe DbExportJob do
  let(:user) { create(:user) }
  let(:storage) { Danbooru.config.storage_manager }
  # Captures the gzipped CSV handed to the storage manager, keyed by file name,
  # so contents can be asserted without touching the filesystem.
  let(:stored) { {} }

  before do
    CurrentUser.user = user
    CurrentUser.ip_addr = "127.0.0.1"

    # Pin a single real storage manager (config builds a new one per call) and
    # intercept only store_db_export, so post creation can still resolve file paths.
    allow(Danbooru.config.custom_configuration).to receive_messages(db_export_enabled?: true, storage_manager: storage)
    allow(storage).to receive(:store_db_export) do |io, file_name|
      io.rewind
      stored[file_name] = Zlib::GzipReader.new(io).read
    end
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def perform
    described_class.perform_now
  end

  def export_csv(name)
    perform
    stored["#{name}.csv.gz"]
  end

  describe "#perform" do
    it "stores a gzipped CSV for every configured export" do
      perform
      DbExportJob::EXPORTS.each_key do |name|
        expect(stored).to have_key("#{name}.csv.gz")
      end
    end

    it "records a DbExport row for each export" do
      expect { perform }.to change(DbExport, :count).by(DbExportJob::EXPORTS.size)
    end

    it "records the file size and generation time" do
      perform
      export = DbExport.find_by(name: "tags")
      expect(export.file_size).to be_positive
      expect(export.updated_at).to be_present
    end

    it "reuses the existing row on a subsequent run" do
      perform
      expect { perform }.not_to change(DbExport, :count)
    end

    it "does nothing when exports are disabled" do
      allow(Danbooru.config.custom_configuration).to receive(:db_export_enabled?).and_return(false)
      expect { perform }.not_to change(DbExport, :count)
      expect(stored).to be_empty
    end

    it "continues when an individual export fails" do
      allow(ActiveRecord::Base.connection).to receive(:reconnect!)
      call_count = 0
      allow(storage).to receive(:store_db_export) do |_io, file_name|
        call_count += 1
        raise StandardError, "boom" if file_name == "posts.csv.gz"
      end

      perform

      expect(call_count).to eq(DbExportJob::EXPORTS.size)
      expect(DbExport.where(name: "posts").exists?).to be false
      expect(DbExport.where(name: "tags").exists?).to be true
    end

    context "with exported contents" do
      it "exports posts" do
        post = create(:post)
        expect(export_csv("posts")).to include(post.md5)
      end

      it "exports tags" do
        create(:tag, name: "test_export_tag")
        expect(export_csv("tags")).to include("test_export_tag")
      end

      it "exports pools" do
        create(:pool, name: "test_export_pool")
        expect(export_csv("pools")).to include("test_export_pool")
      end

      it "exports wiki pages" do
        create(:wiki_page, title: "test_export_wiki")
        expect(export_csv("wiki_pages")).to include("test_export_wiki")
      end

      it "exports artists" do
        create(:artist, name: "test_export_artist")
        expect(export_csv("artists")).to include("test_export_artist")
      end

      it "exports post versions for visible changes" do
        post = create(:post)
        post.update!(tag_string: "new_export_tag")
        expect(export_csv("post_versions")).to include("new_export_tag")
      end

      it "exports approved and original replacements but not pending, rejected, or promoted ones" do
        post = create(:post)
        approved = create(:approved_post_replacement, post: post)
        original = create(:original_post_replacement, post: post)
        pending = create(:post_replacement, post: post)
        rejected = create(:rejected_post_replacement, post: post)
        promoted = create(:promoted_post_replacement, post: post)

        csv = export_csv("post_replacements")
        expect(csv).to include(approved.md5, original.md5)
        expect(csv).not_to include(pending.md5, rejected.md5, promoted.md5)
      end
    end
  end
end
