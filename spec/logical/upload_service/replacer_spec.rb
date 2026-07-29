# frozen_string_literal: true

require "rails_helper"

# Exercises the upload-karma side effects of UploadService::Replacer#process!, which are
# otherwise uncovered: PostReplacement#approve! specs mock the Replacer, and the request specs
# mock approve!. The file pipeline (Upload creation + processing, storage, sample/iqdb work) is
# stubbed so the spec isolates the karma bookkeeping.
RSpec.describe UploadService::Replacer do
  include_context "as admin"

  let(:uploader)      { create(:user) } # original post uploader / previous uploader
  let(:replacer_user) { create(:user) } # suggests + owns the replacement
  let(:post)          { create(:post, uploader: uploader) }
  let(:storage)       { instance_spy(StorageManager) }

  before do
    allow(Danbooru.config.custom_configuration).to receive_messages(storage_manager: storage)
    # Keep post creation off the real storage: skip the AI check and make the thumbnail/AI
    # file lookups resolve to a (non-existent) string path so callbacks return early.
    allow(Setting).to receive_messages(automatic_ai_check: false)
    allow(storage).to receive(:post_file_path).and_return("/tmp/replacer_spec_no_such_file")
  end

  # Runs the real process! control flow (including its karma updates) with the file machinery
  # stubbed. The stubbed upload carries the post's own md5/dimensions so md5_changed is false
  # and the file-cleanup branch is skipped.
  def process!(replacement, penalize:)
    upload = build(:upload,
                   uploader:     replacer_user,
                   md5:          post.md5,
                   file_ext:     post.file_ext,
                   image_width:  post.image_width,
                   image_height: post.image_height,
                   file_size:    post.file_size,
                   tag_string:   post.tag_string)
    file_stub = instance_double(File, path: "/tmp/replacer_spec_no_such_file")
    allow(upload).to receive_messages(
      invalid?: false, is_errored?: false, save!: true, update: true,
      file: file_stub, is_animated_file?: false, video_duration: nil
    )
    allow(upload).to receive(:file=)
    allow(Upload).to receive(:create).and_return(upload)
    allow(UploadService::Utils).to receive(:get_file_for_upload).and_return(file_stub)
    allow(UploadService::Utils).to receive(:process_file)
    allow(post).to receive(:update_iqdb_async)

    described_class.new(post: post, replacement: replacement).process!(penalize_current_uploader: penalize)
  end

  context "replacing another user's live post" do
    let(:replacement) { create(:post_replacement, post: post, creator: replacer_user) }

    it "credits the replacer +1" do
      expect { process!(replacement, penalize: false) }
        .to change { replacer_user.user_status.reload.upload_karma }.by(1)
    end

    it "penalizes the previous uploader -3 when the penalty is set" do
      expect { process!(replacement, penalize: true) }
        .to change { uploader.user_status.reload.upload_karma }.by(-3)
    end

    it "does not penalize the previous uploader when the penalty is not set" do
      expect { process!(replacement, penalize: false) }
        .not_to(change { uploader.user_status.reload.upload_karma })
    end

    it "records the penalty flag and previous uploader so toggle_penalize! reverses symmetrically" do
      process!(replacement, penalize: true)
      expect(replacement.reload.penalize_uploader_on_approve).to be true
      expect(replacement.uploader_id_on_approve).to eq(uploader.id)
    end
  end

  context "replacing one's own post" do
    let(:replacement) { create(:post_replacement, post: post, creator: uploader) }

    it "does not credit the replacer" do
      expect { process!(replacement, penalize: false) }
        .not_to(change { uploader.user_status.reload.upload_karma })
    end
  end

  context "replacing a post that is still pending" do
    let(:replacement) { create(:post_replacement, post: post, creator: replacer_user) }

    before { post.update_columns(is_pending: true) }

    it "does not credit the replacer yet (the +1 is paid on the post's approval instead)" do
      expect { process!(replacement, penalize: false) }
        .not_to(change { replacer_user.user_status.reload.upload_karma })
    end

    it "credits the replacer exactly once, on the post's eventual approval" do
      process!(replacement, penalize: false)
      expect(post.reload.uploader_id).to eq(replacer_user.id)
      expect { post.approve! }
        .to change { replacer_user.user_status.reload.upload_karma }.by(1)
    end
  end
end
