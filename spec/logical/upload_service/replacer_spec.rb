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
    # The retired-penalty reversal on reset-to routes through toggle_penalize!, which logs one.
    allow(PostEvent).to receive(:add)
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

    it "transfers the ownership credit: away from the previous owner, to the replacer" do
      expect { process!(replacement, penalize: false) }
        .to change { uploader.user_status.reload.upload_karma }.by(-UserStatus::KARMA_APPROVED_CREDIT)
        .and change { replacer_user.user_status.reload.upload_karma }.by(UserStatus::KARMA_APPROVED_CREDIT)
    end

    it "additionally penalizes the previous owner when penalized (credit transfer plus replacement penalty)" do
      expect { process!(replacement, penalize: true) }
        .to change { uploader.user_status.reload.upload_karma }.by(-(UserStatus::KARMA_REPLACEMENT_PENALTY + UserStatus::KARMA_APPROVED_CREDIT))
    end

    it "still credits the replacer when penalized" do
      expect { process!(replacement, penalize: true) }
        .to change { replacer_user.user_status.reload.upload_karma }.by(UserStatus::KARMA_APPROVED_CREDIT)
    end

    it "records the penalty flag and previous uploader so toggle_penalize! reverses symmetrically" do
      process!(replacement, penalize: true)
      expect(replacement.reload.penalize_uploader_on_approve).to be true
      expect(replacement.uploader_id_on_approve).to eq(uploader.id)
    end

    it "records a replacement_transfer ledger row for each side of the credit move" do
      process!(replacement, penalize: false)
      events = UploadKarmaEvent.where(reason: :replacement_transfer, post_id: post.id)
      expect(events.pluck(:user_id, :delta)).to contain_exactly(
        [uploader.id, -UserStatus::KARMA_APPROVED_CREDIT],
        [replacer_user.id, UserStatus::KARMA_APPROVED_CREDIT],
      )
      expect(events.pluck(:extra_data).uniq).to eq(
        [{ "replacement_id" => replacement.id, "from" => uploader.id, "to" => replacer_user.id }],
      )
    end

    it "records a replacement_penalty ledger row when penalized" do
      process!(replacement, penalize: true)
      expect(UploadKarmaEvent.find_by(reason: :replacement_penalty)).to have_attributes(
        user_id: uploader.id,
        post_id: post.id,
        delta: -UserStatus::KARMA_REPLACEMENT_PENALTY,
        extra_data: { "replacement_id" => replacement.id },
      )
    end
  end

  context "reset-to (handing ownership back to a previous version)" do
    # The post is currently owned by replacer_user (their replacement is live); resetting to the
    # original backup (created by `uploader`) must MOVE the credit back, not mint a duplicate.
    let(:original) { create(:original_post_replacement, post: post, creator: uploader, md5: SecureRandom.hex(16)) }

    before { post.update_columns(uploader_id: replacer_user.id) }

    it "transfers the ownership credit back: away from the current owner, to the restored owner" do
      expect { process!(original, penalize: false) }
        .to change { replacer_user.user_status.reload.upload_karma }.by(-UserStatus::KARMA_APPROVED_CREDIT)
        .and change { uploader.user_status.reload.upload_karma }.by(UserStatus::KARMA_APPROVED_CREDIT)
    end

    context "when the retired replacement had penalized the previous uploader" do
      # replacer_user's currently-live replacement penalized `uploader`. Reverting to the
      # original must hand that penalty back, not leave `uploader` stuck with it.
      let!(:retired) do
        create(:post_replacement, post: post, creator: replacer_user, status: "approved",
                                  md5: post.md5, penalize_uploader_on_approve: true,
                                  uploader_id_on_approve: uploader.id)
      end

      it "returns the penalty on top of the ownership credit to the restored uploader" do
        expect { process!(original, penalize: false) }
          .to change { uploader.user_status.reload.upload_karma }.by(UserStatus::KARMA_REPLACEMENT_PENALTY + UserStatus::KARMA_APPROVED_CREDIT)
          .and change { replacer_user.user_status.reload.upload_karma }.by(-UserStatus::KARMA_APPROVED_CREDIT)
      end

      it "clears the penalty flag on the retired replacement" do
        process!(original, penalize: false)
        expect(retired.reload.penalize_uploader_on_approve).to be false
      end

      it "decrements the previous uploader's own_post_replaced_penalize_count" do
        expect { process!(original, penalize: false) }
          .to change { uploader.user_status.reload.own_post_replaced_penalize_count }.by(-1)
      end
    end
  end

  context "forward replacement does not reverse an earlier penalty" do
    # A penalized replacement by replacer_user is currently live (it penalized `uploader`).
    # A brand-new (pending) replacement by a third user is a forward replace, not a revert,
    # so `uploader`'s standing penalty must be left in place.
    let(:third)   { create(:user) }
    let(:forward) { create(:post_replacement, post: post, creator: third, status: "pending") }
    let!(:retired) do
      create(:post_replacement, post: post, creator: replacer_user, status: "approved",
                                md5: post.md5, penalize_uploader_on_approve: true,
                                uploader_id_on_approve: uploader.id)
    end

    before { post.update_columns(uploader_id: replacer_user.id) }

    it "leaves the earlier penalty untouched" do
      expect { process!(forward, penalize: false) }
        .not_to(change { uploader.user_status.reload.upload_karma })
      expect(retired.reload.penalize_uploader_on_approve).to be true
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

    it "does not credit the replacer yet (the credit is paid on the post's approval instead)" do
      expect { process!(replacement, penalize: false) }
        .not_to(change { replacer_user.user_status.reload.upload_karma })
    end

    it "credits the replacer exactly once, on the post's eventual approval" do
      process!(replacement, penalize: false)
      expect(post.reload.uploader_id).to eq(replacer_user.id)
      expect { post.approve! }
        .to change { replacer_user.user_status.reload.upload_karma }.by(UserStatus::KARMA_APPROVED_CREDIT)
    end
  end
end
