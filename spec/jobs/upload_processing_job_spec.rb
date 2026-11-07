# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadProcessingJob do
  include_context "as admin"

  let(:member)  { create(:user, created_at: 2.weeks.ago) }
  let(:storage) { instance_spy(StorageManager) }
  let(:fixture) { file_fixture("sample.jpg").to_s }
  let(:upload) do
    create(:upload,
           uploader:             member,
           uploader_ip_addr:     "127.0.0.1",
           status:               "queued",
           md5:                  SecureRandom.hex(16),
           file_ext:             "jpg",
           file_size:            10_000,
           image_width:          500,
           image_height:         500,
           rating:               "s",
           tag_string:           "tagme foo bar",
           submitted_tag_string: "tagme foo bar")
  end

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(storage_manager: storage, backup_storage_manager: instance_spy(StorageManager))
    allow(Setting).to receive_messages(automatic_ai_check: false)
    allow(storage).to receive(:post_file_path).and_return(fixture)
    allow(ImageSampler).to receive(:generate_post_images)
  end

  def perform(id = upload.id, mode = "upload")
    described_class.new.perform(id, mode)
  end

  describe "sidekiq options" do
    it "runs on the uploads queue with a per-argument lock and no Sidekiq retries" do
      options = described_class.get_sidekiq_options
      expect(options).to include("queue" => "uploads", "lock" => :until_and_while_executing, "retry" => 0)
      expect(described_class.lock_args([5, "post"])).to eq([5, "post"])
    end
  end

  describe "#perform in upload mode" do
    it "creates the post as the uploader and completes the upload" do
      expect { perform }.to change(Post, :count).by(1)
      upload.reload
      post = Post.find(upload.post_id)
      expect(upload).to have_attributes(status: "completed", processing_step: nil, has_sound: false)
      expect(upload.processed_at).to be_present
      expect(upload.processing_started_at).to be_present
      expect(post.uploader_id).to eq(member.id)
      expect(post.versions.first.updater_id).to eq(member.id)
    end

    it "generates previews from the stored original before the post exists" do
      allow(ImageSampler).to receive(:generate_post_images) do |stub|
        expect(stub).not_to be_persisted
        expect(stub.md5).to eq(upload.md5)
        expect(Post.where(md5: upload.md5)).not_to exist
      end
      perform
      expect(ImageSampler).to have_received(:generate_post_images).once
    end

    it "records tag warnings for the poll response" do
      perform
      expect(upload.reload.warning_messages).to include(a_string_including("at least 10 general tags"))
    end

    it "dmails very long warning lists instead" do
      long_post = instance_double(Post, id: 1, warnings: ActiveModel::Errors.new(Post.new).tap { |e| e.add(:base, "x" * 1600) })
      allow(UploadService).to receive(:new).and_return(instance_double(UploadService, create_post_from_upload: long_post))
      allow(Dmail).to receive(:create_automated)
      perform
      expect(Dmail).to have_received(:create_automated).with(hash_including(to_id: member.id))
      expect(upload.reload.warning_messages).to eq(["This upload created a LOT of notices. They have been dmailed to you. Please review them"])
    end

    it "does nothing for terminal uploads" do
      upload.update_columns(status: "completed")
      perform
      expect(ImageSampler).not_to have_received(:generate_post_images)
    end

    it "does nothing when the upload no longer exists" do
      expect { perform(0) }.not_to raise_error
    end

    context "when the file is corrupt" do
      let(:fixture) { file_fixture("file_validator/corrupt.jpg").to_s }

      it "fails the upload without creating a post" do
        expect { perform }.not_to change(Post, :count)
        expect(upload.reload).to have_attributes(status: "failed", error_message: "file is corrupt", processing_step: nil)
        expect(ImageSampler).not_to have_received(:generate_post_images)
      end
    end

    context "when the original is missing from storage" do
      let(:fixture) { "/tmp/upload_processing_job_spec_no_such_file" }

      it "fails the upload" do
        perform
        expect(upload.reload).to have_attributes(status: "failed", error_message: "original file is missing from storage")
      end
    end

    context "when a decoder times out" do
      before { allow(ImageSampler).to receive(:generate_post_images).and_raise(VipsCommand::TimeoutError, "vips timed out after 60 seconds") }

      it "requeues once" do
        perform
        expect(upload.reload).to have_attributes(status: "queued", processing_step: nil)
        expect(upload.requeued_at).to be_present
        expect(described_class).to have_enqueued_sidekiq_job(upload.id)
      end

      it "fails on the second timeout" do
        upload.update_columns(requeued_at: 1.minute.ago)
        perform
        expect(upload.reload).to have_attributes(status: "failed", error_message: "processing timed out")
      end

      it "fails immediately when requeueing is not allowed" do
        described_class.new.process_upload(upload, requeue: false, scope_user: false)
        expect(upload.reload.status).to eq("failed")
      end
    end

    context "when a step raises an unexpected error" do
      before { allow(ImageSampler).to receive(:generate_post_images).and_raise(RuntimeError, "boom") }

      it "fails the upload with the error and a backtrace" do
        perform
        expect(upload.reload).to have_attributes(status: "failed", error_message: "RuntimeError - boom")
        expect(upload.backtrace).to be_present
      end
    end

    context "when the post is invalid" do
      before do
        invalid_post = Post.new.tap { |p| p.errors.add(:parent, "does not exist") }
        service = instance_double(UploadService)
        allow(service).to receive(:create_post_from_upload).and_raise(ActiveRecord::RecordInvalid.new(invalid_post))
        allow(UploadService).to receive(:new).and_return(service)
      end

      it "fails the upload with the validation message and creates no post" do
        expect { perform }.not_to change(Post, :count)
        expect(upload.reload.status).to eq("failed")
        expect(upload.error_message).to eq("Parent does not exist")
      end
    end

    context "when a post with the same md5 was created in the meantime" do
      let!(:existing) { create(:post, md5: upload.md5) }

      it "marks the upload a duplicate instead of creating a second post" do
        expect { perform }.not_to change(Post, :count)
        expect(upload.reload.status).to eq("duplicate: #{existing.id}")
      end
    end

    context "with a video that has sound" do
      let(:fixture) { file_fixture("sound/tone-aac.mp4").to_s }
      let(:upload) do
        create(:upload, uploader: member, uploader_ip_addr: "127.0.0.1", status: "queued", md5: SecureRandom.hex(16),
                        file_ext: "mp4", file_size: File.size(fixture), image_width: 500, image_height: 500, rating: "s",
                        tag_string: "tagme foo", submitted_tag_string: "tagme foo", is_animated: true, duration: 2.0)
      end

      it "detects the audio and tags the post" do
        perform
        expect(upload.reload.has_sound).to be true
        expect(Post.find(upload.post_id).tag_array).to include("sound")
      end
    end
  end

  describe "#perform in post mode" do
    it "regenerates the previews of an existing post" do
      post = create(:post)
      perform(post.id, "post")
      expect(ImageSampler).to have_received(:generate_post_images).with(post)
    end

    it "ignores a missing post" do
      expect { perform(0, "post") }.not_to raise_error
    end

    it "rejects unknown modes" do
      expect { perform(1, "bogus") }.to raise_error(ArgumentError)
    end
  end
end
