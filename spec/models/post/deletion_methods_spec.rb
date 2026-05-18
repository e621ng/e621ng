# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "DeletionMethods" do
    describe "#delete!" do
      it "marks the post as deleted" do
        post = create(:post)
        post.delete!("Test deletion reason")
        expect(post.reload.is_deleted).to be true
      end

      it "clears the pending flag on deletion" do
        post = create(:pending_post)
        post.delete!("Test deletion reason")
        expect(post.reload.is_pending).to be false
      end

      it "clears the flagged flag on deletion" do
        post = create(:flagged_post)
        post.delete!("Test deletion reason")
        expect(post.reload.is_flagged).to be false
      end

      it "creates a deletion PostFlag record" do
        post = create(:post)
        expect { post.delete!("Test reason") }.to change(PostFlag, :count).by(1)
      end

      it "marks the created flag as a deletion flag" do
        post = create(:post)
        post.delete!("Test reason")
        flag = post.deletion_flag
        expect(flag.is_deletion).to be true
      end

      it "returns false and adds an error when the post is status-locked" do
        post = create(:status_locked_post)
        result = post.delete!("Test reason")
        expect(result).to be false
        expect(post.errors[:is_status_locked]).to be_present
      end

      # FIXME: Rework after adding a PostReplacement factory
      # it "rejects pending replacements on deletion" do
      #   post = create(:post)
      #   replacement = PostReplacement.create!(
      #     post: post,
      #     creator: create(:user),
      #     creator_ip_addr: "127.0.0.1",
      #     replacement_url: "https://example.com/new.jpg",
      #     status: "pending"
      #   )
      #   post.delete!("Test reason")
      #   expect(replacement.reload.status).to eq("rejected")
      # end
    end

    describe "#undelete!" do
      it "restores the post (clears is_deleted)" do
        post = create(:deleted_post)
        post.undelete!
        expect(post.reload.is_deleted).to be false
      end

      it "marks the post as not pending after undeletion" do
        post = create(:deleted_post)
        post.undelete!
        expect(post.reload.is_pending).to be false
      end

      # FIXME: It definitely does not do this.
      # it "creates a PostApproval record on undeletion" do
      #   post = create(:deleted_post)
      #   expect { post.undelete! }.to change(PostApproval, :count).by(1)
      # end

      it "adds an error when the post is not deleted" do
        post = create(:post, is_deleted: false)
        post.undelete!
        expect(post.errors[:base]).to be_present
      end

      it "adds an error when the post is status-locked" do
        post = create(:deleted_post)
        post.update_columns(is_status_locked: true)
        post.reload.undelete!
        expect(post.errors[:is_status_locked]).to be_present
      end

      it "raises PrivilegeError when a non-admin uploader tries to undelete their own post" do
        member = create(:user)
        post = create(:deleted_post, uploader: member)

        CurrentUser.user = member
        CurrentUser.ip_addr = "127.0.0.1"

        expect { post.undelete! }.to raise_error(User::PrivilegeError)
      end
    end

    describe "#expunge!" do
      it "permanently destroys the post record" do
        post = create(:post)
        post_id = post.id
        post.expunge!
        expect(Post.exists?(post_id)).to be false
      end

      it "creates a DestroyedPost backup record" do
        post = create(:post)
        expect { post.expunge! }.to change(DestroyedPost, :count).by(1)
      end

      it "returns false and adds an error when the post is status-locked" do
        post = create(:status_locked_post)
        result = post.expunge!
        expect(result).to be false
        expect(post.errors[:is_status_locked]).to be_present
      end
    end

    describe "#deletion_flag" do
      it "returns nil when no flags exist" do
        post = create(:post)
        expect(post.deletion_flag).to be_nil
      end

      it "returns the most recent PostFlag" do
        post = create(:post)
        post.delete!("First reason")
        expect(post.deletion_flag).to be_a(PostFlag)
      end
    end

    describe "#pending_flag" do
      it "returns nil when no unresolved flags exist" do
        post = create(:post)
        expect(post.pending_flag).to be_nil
      end

      it "returns an unresolved PostFlag" do
        post = create(:post)
        flag = create(:post_flag, post: post)
        expect(post.pending_flag).to eq(flag)
      end

      it "returns nil after flags are resolved" do
        post = create(:post)
        flag = create(:post_flag, post: post)
        flag.resolve!
        expect(post.reload.pending_flag).to be_nil
      end
    end

    describe "#protect_file?" do
      it "returns true when the post is deleted" do
        expect(create(:deleted_post).protect_file?).to be true
      end

      it "returns false when the post is not deleted" do
        expect(create(:post).protect_file?).to be false
      end
    end

    describe "#delete! with blank reason" do
      it "adds an error when there is no active flag and the reason is blank" do
        post = create(:post)
        post.delete!("")
        expect(post.errors[:base]).to be_present
        expect(post.errors[:base].join).to match(/no active flag/)
      end

      it "adds an error when the pending flag has an uploading_guidelines reason" do
        skip "uploading_guidelines reason not present in config" unless Danbooru.config.flag_reasons.any? { |r| r[:name].to_s == "uploading_guidelines" }
        post = create(:post)
        create(:post_flag, post: post, reason_name: "uploading_guidelines", note: "Does not meet uploading guidelines.")
        post.delete!("")
        expect(post.errors[:base].join).to match(/uploading guidelines/)
      end

      it "uses the pending flag's reason when the reason is blank and a valid flag exists" do
        post = create(:post)
        create(:post_flag, post: post)
        expect { post.delete!("") }.to change { post.reload.is_deleted }.to(true)
      end
    end

    describe "#substitute_deletion_dmail_template" do
      it "returns nil when the text is blank" do
        post = create(:post)
        expect(post.substitute_deletion_dmail_template("")).to be_nil
        expect(post.substitute_deletion_dmail_template(nil)).to be_nil
      end

      it "substitutes %POST_ID% with the post id" do
        post = create(:post)
        result = post.substitute_deletion_dmail_template("Post #%POST_ID%")
        expect(result).to include(post.id.to_s)
      end

      it "substitutes %FLAG_ID% with the deletion flag id" do
        post = create(:post)
        post.delete!("bogus")
        result = post.substitute_deletion_dmail_template("Post #%FLAG_ID%")
        expect(result).to include(post.deletion_flag.id.to_s)
      end

      it "substitutes %REASON% when a reason is provided" do
        post = create(:post)
        result = post.substitute_deletion_dmail_template("Reason: %REASON%", "test reason")
        expect(result).to include("test reason")
      end

      it "leaves %REASON% unchanged when no reason is given" do
        post = create(:post)
        result = post.substitute_deletion_dmail_template("Reason: %REASON%")
        expect(result).to include("%REASON%")
      end

      it "substitutes %STAFF_NAME% with the current user name" do
        post = create(:post)
        result = post.substitute_deletion_dmail_template("Staff: %STAFF_NAME%")
        expect(result).to include(CurrentUser.name)
      end
    end
  end
end
