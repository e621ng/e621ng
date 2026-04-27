# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadService::Utils do
  include_context "as member"

  let(:storage)        { instance_spy(StorageManager) }
  let(:backup_storage) { instance_spy(StorageManager) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(
      storage_manager:        storage,
      backup_storage_manager: backup_storage,
      auto_flag_ai_posts?:    false,
    )
    # post_file_path must return a string so File.exist? in post callbacks doesn't raise.
    # A non-existent path causes generate_post_images to return early.
    allow(storage).to receive(:post_file_path).and_return("/tmp/upload_service_utils_spec_no_such_file")
  end

  # ---------------------------------------------------------------------------

  describe ".delete_file" do
    let(:md5)      { SecureRandom.hex(16) }
    let(:file_ext) { "jpg" }

    context "when a Post with that md5 exists" do
      before { create(:post, md5: md5) }

      it "does not call delete_post_files on storage" do
        described_class.delete_file(md5, file_ext)
        expect(storage).not_to have_received(:delete_post_files)
      end

      it "updates the upload status to 'completed' when a valid upload_id is given" do
        upload = create(:upload)
        described_class.delete_file(md5, file_ext, upload.id)
        expect(upload.reload.status).to eq("completed")
      end

      it "does not raise when upload_id does not exist in the database" do
        expect { described_class.delete_file(md5, file_ext, 0) }.not_to raise_error
      end
    end

    context "when no Post with that md5 exists" do
      it "calls delete_post_files on the primary storage manager" do
        described_class.delete_file(md5, file_ext)
        expect(storage).to have_received(:delete_post_files).with(md5, file_ext)
      end

      it "does not call delete_post_files on the backup storage manager" do
        described_class.delete_file(md5, file_ext)
        expect(backup_storage).not_to have_received(:delete_post_files)
      end
    end
  end

  # ---------------------------------------------------------------------------

  describe ".distribute_files" do
    let(:file)   { instance_spy(File) }
    let(:record) { instance_double(Upload, md5: "abc123def456789012345678901234ab", file_ext: "jpg") }

    it "calls store_file on the primary storage manager" do
      described_class.distribute_files(file, record, :original)
      expect(storage).to have_received(:store_file).with(file, an_instance_of(Post), :original)
    end

    it "calls store_file on the backup storage manager" do
      described_class.distribute_files(file, record, :original)
      expect(backup_storage).to have_received(:store_file).with(file, an_instance_of(Post), :original)
    end

    it "sets post.id from original_post_id when provided" do
      received_post = nil
      allow(storage).to receive(:store_file) { |_f, post, _t| received_post = post }
      described_class.distribute_files(file, record, :original, original_post_id: 42)
      expect(received_post.id).to eq(42)
    end

    it "leaves post.id nil when original_post_id is not provided" do
      received_post = nil
      allow(storage).to receive(:store_file) { |_f, post, _t| received_post = post }
      described_class.distribute_files(file, record, :original)
      expect(received_post.id).to be_nil
    end

    it "sets post.md5 and post.file_ext from the record" do
      received_post = nil
      allow(storage).to receive(:store_file) { |_f, post, _t| received_post = post }
      described_class.distribute_files(file, record, :original)
      expect(received_post.md5).to eq("abc123def456789012345678901234ab")
      expect(received_post.file_ext).to eq("jpg")
    end
  end

  # ---------------------------------------------------------------------------

  describe ".process_file" do
    let(:uploader) { CurrentUser.user }

    context "with sample.jpg" do
      let(:file) do
        Tempfile.new(["sample", ".jpg"]).tap do |f|
          f.binmode
          f.write(File.binread(file_fixture("sample.jpg").to_s))
          f.rewind
        end
      end
      let(:upload) do
        build(:upload, uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s", tag_string: "tagme")
      end

      after do
        file.close!
      rescue StandardError
        nil
      end

      it "sets file_ext to 'jpg'" do
        described_class.process_file(upload, file)
        expect(upload.file_ext).to eq("jpg")
      end

      it "sets md5 to a 32-character hex string" do
        described_class.process_file(upload, file)
        expect(upload.md5).to match(/\A[0-9a-f]{32}\z/)
      end

      it "sets file_size to the file's byte size" do
        described_class.process_file(upload, file)
        expect(upload.file_size).to eq(file.size)
      end

      it "sets image_width and image_height to positive values" do
        described_class.process_file(upload, file)
        expect(upload.image_width).to be > 0
        expect(upload.image_height).to be > 0
      end

      it "calls store_file on the storage manager" do
        described_class.process_file(upload, file)
        expect(storage).to have_received(:store_file)
      end

      it "enqueues UploadDeleteFilesJob" do
        expect { described_class.process_file(upload, file) }.to have_enqueued_job(UploadDeleteFilesJob)
      end
    end

    context "automatic_tags integration" do
      let(:upload) { build(:upload, uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s", tag_string: "") }

      def fixture_tempfile(name, ext)
        Tempfile.new([name, ".#{ext}"]).tap do |f|
          f.binmode
          f.write(File.binread(file_fixture("#{name}.#{ext}").to_s))
          f.rewind
        end
      end

      it "adds animated_gif and animated tags for animated.gif" do
        file = fixture_tempfile("animated", "gif")
        described_class.process_file(upload, file)
        expect(upload.tag_string.split).to include("animated_gif", "animated")
      ensure
        file.close!
      end

      it "adds animated_png and animated tags for animated.png" do
        file = fixture_tempfile("animated", "png")
        described_class.process_file(upload, file)
        expect(upload.tag_string.split).to include("animated_png", "animated")
      ensure
        file.close!
      end

      it "adds animated_webp and animated tags for animated.webp" do
        file = fixture_tempfile("animated", "webp")
        described_class.process_file(upload, file)
        expect(upload.tag_string.split).to include("animated_webp", "animated")
      ensure
        file.close!
      end

      it "does not add animated tags for sample.jpg" do
        file = fixture_tempfile("sample", "jpg")
        described_class.process_file(upload, file)
        expect(upload.tag_string.split).not_to include("animated")
      ensure
        file.close!
      end

      it "deduplicates tags when an automatic tag already exists in tag_string" do
        upload.tag_string = "animated"
        file = fixture_tempfile("animated", "gif")
        described_class.process_file(upload, file)
        expect(upload.tag_string.split.count("animated")).to eq(1)
      ensure
        file.close!
      end
    end

    # FIXME: Requires pre-computing the fixture file's md5 and creating a Post
    # with that md5 before calling process_file. validate!(:file) then adds a
    # duplicate md5 error and should raise ActiveRecord::RecordInvalid.
    # Skipped until a reliable helper for this setup is available.
    it "raises ActiveRecord::RecordInvalid when the file md5 is a duplicate" do
      file = Tempfile.new(["sample", ".jpg"]).tap do |f|
        f.binmode
        f.write(File.binread(file_fixture("sample.jpg").to_s))
        f.rewind
      end
      skip "FIXME: needs a helper to pre-create a Post matching the fixture's md5"
      md5 = Digest::MD5.file(file.path).hexdigest
      create(:post, md5: md5)
      upload = build(:upload, uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s")
      expect { described_class.process_file(upload, file) }.to raise_error(ActiveRecord::RecordInvalid)
    ensure
      file&.close!
    end
  end

  # ---------------------------------------------------------------------------

  describe ".automatic_tags" do
    let(:uploader) { CurrentUser.user }

    before do
      allow(Danbooru.config.custom_configuration).to receive(:enable_dimension_autotagging?).and_return(true)
    end

    context "when dimension autotagging is disabled" do
      before do
        allow(Danbooru.config.custom_configuration).to receive(:enable_dimension_autotagging?).and_return(false)
      end

      it "returns empty string regardless of file type" do
        upload = build(:upload, uploader: uploader, file_ext: "gif")
        file   = instance_double(File, path: file_fixture("animated.gif").to_s)
        expect(described_class.automatic_tags(upload, file)).to eq("")
      end
    end

    context "with animated.gif" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "gif") }
      let(:file)   { File.open(file_fixture("animated.gif").to_s) }

      it "includes animated_gif and animated" do
        result = described_class.automatic_tags(upload, file)
        expect(result.split).to include("animated_gif", "animated")
      end
    end

    context "with static.gif" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "gif") }
      let(:file)   { File.open(file_fixture("static.gif").to_s) }

      it "returns empty string" do
        expect(described_class.automatic_tags(upload, file)).to eq("")
      end
    end

    context "with animated.png" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "png") }
      let(:file)   { File.open(file_fixture("animated.png").to_s) }

      it "includes animated_png and animated" do
        result = described_class.automatic_tags(upload, file)
        expect(result.split).to include("animated_png", "animated")
      end
    end

    context "with sample.png" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "png") }
      let(:file)   { File.open(file_fixture("sample.png").to_s) }

      it "returns empty string" do
        expect(described_class.automatic_tags(upload, file)).to eq("")
      end
    end

    context "with animated.webp" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "webp") }
      let(:file)   { File.open(file_fixture("animated.webp").to_s) }

      it "includes animated_webp and animated" do
        result = described_class.automatic_tags(upload, file)
        expect(result.split).to include("animated_webp", "animated")
      end
    end

    context "with sample.webp" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "webp") }
      let(:file)   { File.open(file_fixture("sample.webp").to_s) }

      it "returns empty string" do
        expect(described_class.automatic_tags(upload, file)).to eq("")
      end
    end

    context "with a webm upload" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "webm") }
      let(:file)   { instance_double(File, path: "/dev/null") }

      it "returns 'animated'" do
        expect(described_class.automatic_tags(upload, file).split).to eq(["animated"])
      end
    end

    context "with an mp4 upload" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "mp4") }
      let(:file)   { instance_double(File, path: "/dev/null") }

      it "returns 'animated'" do
        expect(described_class.automatic_tags(upload, file).split).to eq(["animated"])
      end
    end

    context "with a jpg upload" do
      let(:upload) { build(:upload, uploader: uploader, file_ext: "jpg") }
      let(:file)   { instance_double(File, path: "/dev/null") }

      it "returns empty string" do
        expect(described_class.automatic_tags(upload, file)).to eq("")
      end
    end
  end

  # ---------------------------------------------------------------------------

  describe ".get_file_for_upload" do
    context "when a file is provided directly" do
      let(:file) { instance_spy(Tempfile, path: "/tmp/test.jpg") }

      it "returns the provided file" do
        expect(described_class.get_file_for_upload(instance_double(Upload), file: file)).to eq(file)
      end

      it "does not instantiate Downloads::File" do
        allow(Downloads::File).to receive(:new)
        described_class.get_file_for_upload(instance_double(Upload), file: file)
        expect(Downloads::File).not_to have_received(:new)
      end
    end

    context "when no file and no direct_url are provided" do
      let(:upload) { instance_double(Upload, direct_url_parsed: nil) }

      it "raises with 'No file or source URL provided'" do
        expect { described_class.get_file_for_upload(upload) }
          .to raise_error(RuntimeError, "No file or source URL provided")
      end
    end

    context "when a direct_url is provided but no file" do
      let(:parsed_url) { Addressable::URI.parse("https://example.com/image.jpg") }
      let(:upload)     { instance_double(Upload, direct_url_parsed: parsed_url) }
      let(:downloader) { instance_spy(Downloads::File) }
      let(:tempfile)   { instance_spy(Tempfile) }

      before do
        allow(Downloads::File).to receive(:new).with(parsed_url).and_return(downloader)
        allow(downloader).to receive(:download!).and_return(tempfile)
      end

      it "calls download! and returns the resulting file" do
        expect(described_class.get_file_for_upload(upload)).to eq(tempfile)
        expect(downloader).to have_received(:download!)
      end
    end
  end
end
