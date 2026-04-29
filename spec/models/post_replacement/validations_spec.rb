# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     PostReplacement Validations                             #
# --------------------------------------------------------------------------- #

RSpec.describe PostReplacement do
  include_context "as admin"

  # All PostReplacement validators fire `on: :create`.  Calling `valid?` on a
  # new (unsaved) record sets the context to :create, triggering them all.
  # Most validators involve real file I/O; the helper below stubs them out so
  # individual validators can be tested in isolation.
  def stub_file_validators(record)
    %i[set_file_name fetch_source_file update_file_attributes write_storage_file].each do |m|
      allow(record).to receive(m)
    end
    allow(FileValidator).to receive(:new).and_return(instance_double(FileValidator, "validator", validate: nil))
  end

  # --------------------------------------------------------------------------
  # reason (inline block + length validator)
  # --------------------------------------------------------------------------
  describe "reason" do
    it "is invalid when reason is blank" do
      record = build(:post_replacement, reason: "")
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("You must provide a reason.")
    end

    it "is invalid when reason is the reserved phrase 'Backup of original file'" do
      record = build(:post_replacement, reason: "Backup of original file")
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("You cannot use 'Backup of original file' as a reason.")
    end

    it "is invalid when reason is the reserved phrase regardless of casing" do
      record = build(:post_replacement, reason: "BACKUP OF ORIGINAL FILE")
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("You cannot use 'Backup of original file' as a reason.")
    end

    it "is invalid when reason is shorter than 5 characters" do
      record = build(:post_replacement, reason: "abcd")
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is invalid when reason exceeds 150 characters" do
      record = build(:post_replacement, reason: "a" * 151)
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:reason]).to be_present
    end

    it "is valid at exactly 5 characters" do
      record = build(:post_replacement, reason: "abcde")
      stub_file_validators(record)
      expect(record).to be_valid
    end

    it "is valid at exactly 150 characters" do
      record = build(:post_replacement, reason: "a" * 150)
      stub_file_validators(record)
      expect(record).to be_valid
    end

    it "skips the reserved-phrase and blank checks when status is 'original'" do
      record = build(:post_replacement, status: "original", reason: "Backup of original file")
      stub_file_validators(record)
      record.valid?
      expect(record.errors[:base]).not_to include("You cannot use 'Backup of original file' as a reason.")
      expect(record.errors[:base]).not_to include("You must provide a reason.")
    end
  end

  # --------------------------------------------------------------------------
  # post_is_valid
  # --------------------------------------------------------------------------
  describe "post_is_valid" do
    it "is invalid when the post is deleted" do
      post = build(:post, is_deleted: true)
      record = build(:post_replacement, post: post)
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:post]).to be_present
    end

    it "is valid when the post is not deleted" do
      post = build(:post, is_deleted: false)
      record = build(:post_replacement, post: post)
      stub_file_validators(record)
      expect(record).to be_valid
    end
  end

  # --------------------------------------------------------------------------
  # no_pending_duplicates
  # --------------------------------------------------------------------------
  describe "no_pending_duplicates" do
    it "is invalid when an existing post already has the same md5" do
      existing = create(:post)
      record = build(:post_replacement, md5: existing.md5, is_backup: false)
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:md5].first).to include("duplicate of existing post ##{existing.id}")
    end

    it "is invalid when a pending replacement with the same md5 already exists" do
      sibling = create(:post_replacement, status: "pending")
      record = build(:post_replacement, md5: sibling.md5, is_backup: false)
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:md5].first).to include("duplicate of pending replacement on post ##{sibling.post_id}")
    end

    it "is skipped when is_backup is true" do
      existing = create(:post)
      record = build(:post_replacement, md5: existing.md5)
      record.is_backup = true
      stub_file_validators(record)
      record.valid?
      expect(record.errors[:md5]).to be_empty
    end
  end

  # --------------------------------------------------------------------------
  # user_is_not_limited
  # --------------------------------------------------------------------------
  describe "user_is_not_limited" do
    it "is invalid when the creator cannot upload" do
      creator = create(:user)
      allow(creator).to receive(:can_upload_with_reason).and_return(:restricted)
      record = build(:post_replacement, creator: creator)
      stub_file_validators(record)
      expect(record).not_to be_valid
      expect(record.errors[:creator]).to be_present
    end

    it "skips the check when status is 'original'" do
      creator = create(:user)
      allow(creator).to receive(:can_upload_with_reason).and_return(:restricted)
      record = build(:post_replacement, creator: creator, status: "original", reason: "Backup of original file")
      stub_file_validators(record)
      record.valid?
      expect(record.errors[:creator]).to be_empty
    end
  end
end
