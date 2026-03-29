# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       UserFeedback::LogMethods                              #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  # Explicit body and category are set so the log values assertions have stable, known strings.
  def make_feedback(overrides = {})
    create(:user_feedback, user: subject_user, creator: moderator, body: "original body", category: "positive", **overrides)
  end

  describe "log methods" do
    # -------------------------------------------------------------------------
    # #log_create (via after_create)
    # -------------------------------------------------------------------------
    describe "#log_create" do
      it "logs a user_feedback_create action when a record is created" do
        feedback = make_feedback
        log = ModAction.last

        expect(log.action).to eq("user_feedback_create")
        # log[:values] reads the raw jsonb column directly, bypassing the ModAction#values
        # accessor which filters fields based on CurrentUser's level. This keeps the
        # assertions role-agnostic and tests what was actually written to the database.
        expect(log[:values]).to include(
          "user_id"   => subject_user.id,
          "reason"    => "original body",
          "type"      => "positive",
          "record_id" => feedback.id,
        )
      end
    end

    # -------------------------------------------------------------------------
    # #log_destroy (via after_destroy)
    # -------------------------------------------------------------------------
    describe "#log_destroy" do
      it "logs a user_feedback_destroy action when a record is hard-deleted" do
        feedback = make_feedback
        # Capture the id before destruction — the record will be frozen afterward.
        feedback_id = feedback.id
        feedback.destroy!
        log = ModAction.last

        expect(log.action).to eq("user_feedback_destroy")
        expect(log[:values]).to include(
          "user_id"   => subject_user.id,
          "reason"    => "original body",
          "type"      => "positive",
          "record_id" => feedback_id,
        )
      end
    end

    # -------------------------------------------------------------------------
    # #log_update (via after_update) — five branches
    # -------------------------------------------------------------------------
    # log_update has two distinct code paths:
    #
    #   1. is_deleted changed:
    #      - Always logs :user_feedback_delete or :user_feedback_undelete.
    #      - Then returns early UNLESS body or category also changed, in which
    #        case it falls through and additionally logs :user_feedback_update.
    #
    #   2. is_deleted did not change:
    #      - Always logs :user_feedback_update.
    #
    # This yields five observable branches (branches 1–4 involve is_deleted;
    # branch 5 does not).
    describe "#log_update" do
      # Branch 1: is_deleted changed to true, nothing else changed
      it "logs only user_feedback_delete when soft-deleting without other changes" do
        feedback = make_feedback

        expect { feedback.update!(is_deleted: true) }
          .to change(ModAction, :count).by(1)

        expect(ModAction.last.action).to eq("user_feedback_delete")
      end

      # Branch 2: is_deleted changed to false (undelete), nothing else changed
      it "logs only user_feedback_undelete when restoring without other changes" do
        feedback = make_feedback(is_deleted: true)
        # make_feedback fires log_create, so we snapshot the count here rather than
        # using change{}.by() to avoid counting that earlier log entry as part of
        # this assertion.
        action_count_before = ModAction.count

        feedback.update!(is_deleted: false)

        expect(ModAction.count - action_count_before).to eq(1)
        expect(ModAction.last.action).to eq("user_feedback_undelete")
      end

      # Branch 3: is_deleted changed to true AND body also changed
      it "logs user_feedback_delete then user_feedback_update when soft-deleting with a body change" do
        feedback = make_feedback

        expect { feedback.update!(is_deleted: true, body: "updated body") }
          .to change(ModAction, :count).by(2)

        # The delete/undelete action is always logged first, then the update.
        # ModAction.last(2) returns records in insertion order (oldest first).
        actions = ModAction.last(2).map(&:action)
        expect(actions).to eq(%w[user_feedback_delete user_feedback_update])
      end

      # Branch 4: is_deleted changed to false AND category also changed
      it "logs user_feedback_undelete then user_feedback_update when restoring with a category change" do
        feedback = make_feedback(is_deleted: true)
        # Same reason as branch 2: snapshot after make_feedback to exclude log_create.
        action_count_before = ModAction.count

        feedback.update!(is_deleted: false, category: "negative")

        expect(ModAction.count - action_count_before).to eq(2)
        actions = ModAction.last(2).map(&:action)
        expect(actions).to eq(%w[user_feedback_undelete user_feedback_update])
      end

      # Branch 5: body/category changed with no is_deleted change
      it "logs only user_feedback_update when editing body or category" do
        feedback = make_feedback

        expect { feedback.update!(body: "revised body", category: "negative") }
          .to change(ModAction, :count).by(1)

        log = ModAction.last
        expect(log.action).to eq("user_feedback_update")
        expect(log[:values]).to include(
          "user_id"    => subject_user.id,
          "reason"     => "revised body",
          "reason_was" => "original body",
          "type"       => "negative",
          "type_was"   => "positive",
          "record_id"  => feedback.id,
        )
      end
    end
  end
end
