# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadService do
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
    allow(storage).to receive(:post_file_path).and_return("/tmp/upload_service_spec_no_such_file")
  end

  # ---------------------------------------------------------------------------

  describe "#initialize" do
    it "stores params without creating an Upload" do
      expect { described_class.new(rating: "s") }.not_to change(Upload, :count)
    end

    it "exposes params via #params" do
      service = described_class.new(rating: "s", tag_string: "foo")
      expect(service.params[:tag_string]).to eq("foo")
    end
  end

  # ---------------------------------------------------------------------------

  describe "#start!" do
    let(:uploader) { CurrentUser.user }

    context "with a valid file upload" do
      let(:file) do
        Tempfile.new(["sample", ".jpg"]).tap do |f|
          f.binmode
          f.write(File.binread(file_fixture("sample.jpg").to_s))
          f.rewind
        end
      end
      let(:params)  { { uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s", file: file } }
      let(:service) { described_class.new(params) }

      after do
        file.close!
      rescue StandardError
        nil
      end

      it "returns an Upload" do
        expect(service.start!).to be_a(Upload)
      end

      it "sets upload status to 'completed'" do
        expect(service.start!.status).to eq("completed")
      end

      it "creates a Post" do
        expect { service.start! }.to change(Post, :count).by(1)
      end

      it "sets upload.post_id to the created post" do
        result = service.start!
        expect(result.post_id).to eq(Post.last.id)
      end

      it "exposes the created post via #post" do
        service.start!
        expect(service.post).to be_a(Post)
      end

      it "enqueues UploadDeleteFilesJob" do
        expect { service.start! }.to have_enqueued_job(UploadDeleteFilesJob)
      end

      it "defaults tag_string to 'tagme' when not provided" do
        service.start!
        expect(Upload.last.tag_string).to include("tagme")
      end
    end

    context "when the Upload is invalid (bad rating)" do
      let(:params)  { { uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "z" } }
      let(:service) { described_class.new(params) }

      it "returns the upload with errors" do
        expect(service.start!.errors).not_to be_empty
      end

      it "does not change upload status from 'pending'" do
        expect(service.start!.status).to eq("pending")
      end

      it "does not call Utils.process_file" do
        allow(UploadService::Utils).to receive(:process_file)
        service.start!
        expect(UploadService::Utils).not_to have_received(:process_file)
      end

      it "does not create a Post" do
        expect { service.start! }.not_to change(Post, :count)
      end
    end

    context "when Utils.process_file raises" do
      let(:file)    { instance_spy(Tempfile, path: file_fixture("sample.jpg").to_s) }
      let(:params)  { { uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s", file: file } }
      let(:service) { described_class.new(params) }

      before do
        allow(UploadService::Utils).to receive(:get_file_for_upload).and_return(file)
        allow(UploadService::Utils).to receive(:process_file).and_raise(RuntimeError, "bad file")
      end

      it "does not propagate the exception" do
        expect { service.start! }.not_to raise_error
      end

      it "sets upload status to an error string" do
        expect(service.start!.status).to match(/\Aerror: RuntimeError - bad file/)
      end

      it "populates upload backtrace" do
        expect(service.start!.backtrace).to be_present
      end

      it "does not create a Post" do
        expect { service.start! }.not_to change(Post, :count)
      end
    end

    context "when no file and no direct_url are provided" do
      let(:params)  { { uploader: uploader, uploader_ip_addr: "127.0.0.1", rating: "s" } }
      let(:service) { described_class.new(params) }

      it "returns upload with an error status" do
        expect(service.start!.status).to match(/\Aerror:/)
      end
    end
  end

  # ---------------------------------------------------------------------------

  describe "#warnings" do
    it "returns [] when no post has been created" do
      expect(described_class.new({}).warnings).to eq([])
    end

    it "returns an Array after a post is assigned" do
      post = create(:post)
      service = described_class.new({})
      service.instance_variable_set(:@post, post)
      expect(service.warnings).to be_an(Array)
    end
  end

  # ---------------------------------------------------------------------------

  describe "#create_post_from_upload" do
    let(:uploader) { CurrentUser.user }
    let(:upload) do
      u = create(:upload,
                 uploader:         uploader,
                 uploader_ip_addr: "127.0.0.1",
                 md5:              SecureRandom.hex(16),
                 file_ext:         "jpg",
                 image_width:      640,
                 image_height:     480,
                 rating:           "s",
                 tag_string:       "tagme",
                 description:      "hello",
                 file_size:        10_000,
                 source:           "")
      u.file = File.open(file_fixture("sample.jpg").to_s)
      u
    end
    let(:service) { described_class.new({}) }

    it "returns the created Post" do
      expect(service.create_post_from_upload(upload)).to be_a(Post)
    end

    it "sets upload.status to 'completed'" do
      service.create_post_from_upload(upload)
      expect(upload.reload.status).to eq("completed")
    end

    it "sets upload.post_id to the new post id" do
      post = service.create_post_from_upload(upload)
      expect(upload.reload.post_id).to eq(post.id)
    end
  end

  # ---------------------------------------------------------------------------

  describe "#convert_to_post" do
    let(:uploader) { CurrentUser.user }
    let(:upload) do
      u = build(:upload,
                uploader:         uploader,
                uploader_ip_addr: "127.0.0.1",
                md5:              SecureRandom.hex(16),
                file_ext:         "jpg",
                image_width:      640,
                image_height:     480,
                rating:           "s",
                tag_string:       "tagme",
                description:      "  hello  ",
                file_size:        10_000,
                source:           "https://example.com",
                parent_id:        nil)
      u.file = File.open(file_fixture("sample.jpg").to_s)
      u
    end
    let(:service) { described_class.new({}) }

    context "basic field mapping" do
      subject(:post) { service.convert_to_post(upload) }

      it "maps tag_string" do
        expect(post.tag_string).to eq(upload.tag_string)
      end

      it "strips description" do
        expect(post.description).to eq("hello")
      end

      it "maps md5" do
        expect(post.md5).to eq(upload.md5)
      end

      it "maps file_ext" do
        expect(post.file_ext).to eq("jpg")
      end

      it "maps image_width" do
        expect(post.image_width).to eq(640)
      end

      it "maps image_height" do
        expect(post.image_height).to eq(480)
      end

      it "maps rating" do
        expect(post.rating).to eq("s")
      end

      it "maps source" do
        expect(post.source).to eq("https://example.com")
      end

      it "maps file_size" do
        expect(post.file_size).to eq(10_000)
      end

      it "maps uploader_id" do
        expect(post.uploader_id).to eq(uploader.id)
      end

      it "maps uploader_ip_addr" do
        expect(post.uploader_ip_addr.to_s).to eq("127.0.0.1")
      end

      it "maps parent_id" do
        parent = create(:post)
        upload.parent_id = parent.id
        expect(service.convert_to_post(upload).parent_id).to eq(parent.id)
      end
    end

    context "is_pending? logic" do
      it "marks post as pending when uploader cannot upload free" do
        allow(upload.uploader).to receive(:can_upload_free?).and_return(false)
        expect(service.convert_to_post(upload).is_pending).to be true
      end

      it "marks post as pending when avoid_posting_artists present and uploader cannot approve" do
        artist = create(:artist)
        create(:avoid_posting, artist: artist)
        upload.tag_string = artist.name
        allow(upload.uploader).to receive_messages(can_upload_free?: true, can_approve_posts?: false)
        expect(service.convert_to_post(upload).is_pending).to be true
      end

      it "marks post as pending when upload_as_pending? is true" do
        allow(upload.uploader).to receive_messages(can_upload_free?: true, can_approve_posts?: true)
        allow(upload).to receive(:upload_as_pending?).and_return(true)
        expect(service.convert_to_post(upload).is_pending).to be true
      end

      it "does not mark post as pending when no pending conditions apply" do
        allow(upload.uploader).to receive_messages(can_upload_free?: true, can_approve_posts?: true)
        allow(upload).to receive(:upload_as_pending?).and_return(false)
        # upload.tag_string is "tagme" which has no artist tags, so avoid_posting_artists is []
        expect(service.convert_to_post(upload).is_pending).to be false
      end
    end

    context "locked_rating" do
      it "sets is_rating_locked when locked_rating is present" do
        upload.locked_rating = true
        expect(service.convert_to_post(upload).is_rating_locked).to be true
      end

      it "does not set is_rating_locked when locked_rating is blank" do
        upload.locked_rating = nil
        expect(service.convert_to_post(upload).is_rating_locked).to be false
      end
    end
  end
end
