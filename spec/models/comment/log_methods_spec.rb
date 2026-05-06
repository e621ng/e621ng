# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Comment::ModAction Logging                            #
# --------------------------------------------------------------------------- #
#
# Comment fires four distinct callback-driven log actions:
#
#   after_update  → :comment_update   (when actor ≠ creator AND is_hidden did NOT change)
#   after_destroy → :comment_delete   (always)
#   after_save    → :comment_hide     (when is_hidden changes to true  AND actor ≠ creator)
#               → :comment_unhide   (when is_hidden changes to false AND actor ≠ creator)
#
# All tests create the comment as `creator`, then switch CurrentUser to `moderator`
# before triggering the action under test, ensuring actor ≠ creator for every
# branch that requires it.

RSpec.describe Comment do
  let(:creator)   { create(:user) }
  let(:moderator) { create(:moderator_user) }

  # Create the comment as the owning user, then hand control to the moderator.
  def make_comment(overrides = {})
    CurrentUser.scoped(creator, "127.0.0.1") { create(:comment, **overrides) }
  end

  before do
    CurrentUser.user    = moderator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # -------------------------------------------------------------------------
  # after_update → :comment_update
  # -------------------------------------------------------------------------
  describe "after_update — comment_update" do
    it "logs a comment_update action when a moderator edits the body" do
      comment = make_comment

      expect { comment.update!(body: "moderator changed this body") }
        .to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("comment_update")
      expect(log[:values]).to include(
        "comment_id" => comment.id,
        "user_id"    => creator.id,
      )
    end

    it "does not log comment_update when the creator edits their own comment" do
      comment = make_comment
      CurrentUser.user = creator

      expect { comment.update!(body: "creator edited this body") }
        .not_to change(ModAction.where(action: "comment_update"), :count)
    end
  end

  # -------------------------------------------------------------------------
  # after_destroy → :comment_delete
  # -------------------------------------------------------------------------
  describe "after_destroy — comment_delete" do
    it "logs a comment_delete action when a comment is hard-deleted" do
      comment    = make_comment
      comment_id = comment.id

      expect { comment.destroy! }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("comment_delete")
      expect(log[:values]).to include(
        "comment_id" => comment_id,
        "user_id"    => creator.id,
      )
    end
  end

  # -------------------------------------------------------------------------
  # after_save (is_hidden toggle) → :comment_hide / :comment_unhide
  # -------------------------------------------------------------------------
  describe "after_save — comment_hide / comment_unhide" do
    it "logs a comment_hide action when a moderator hides a comment" do
      comment = make_comment

      expect { comment.update!(is_hidden: true) }.to change(ModAction, :count).by(1)

      log = ModAction.last
      expect(log.action).to eq("comment_hide")
      expect(log[:values]).to include(
        "comment_id" => comment.id,
        "user_id"    => creator.id,
      )
    end

    it "logs a comment_unhide action when a moderator unhides a comment" do
      comment             = make_comment(is_hidden: true)
      action_count_before = ModAction.count

      comment.update!(is_hidden: false)

      expect(ModAction.count - action_count_before).to eq(1)
      log = ModAction.last
      expect(log.action).to eq("comment_unhide")
      expect(log[:values]).to include(
        "comment_id" => comment.id,
        "user_id"    => creator.id,
      )
    end

    it "does not log comment_hide when the creator hides their own comment" do
      comment = make_comment
      CurrentUser.user = creator

      expect { comment.update!(is_hidden: true) }
        .not_to change(ModAction.where(action: "comment_hide"), :count)
    end
  end
end
