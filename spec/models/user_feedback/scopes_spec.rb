# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           UserFeedback Scopes                               #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  # Helper so individual scope tests don't repeat the full create call.
  def make_feedback(overrides = {})
    create(:user_feedback, user: subject_user, creator: moderator, **overrides)
  end

  # -------------------------------------------------------------------------
  # Scopes
  # -------------------------------------------------------------------------
  describe "scopes" do
    # -------------------------------------------------------------------------
    # .active / .deleted
    # -------------------------------------------------------------------------
    describe ".active" do
      it "returns non-deleted records" do
        active  = make_feedback(is_deleted: false)
        deleted = make_feedback(is_deleted: true)

        expect(UserFeedback.active).to include(active)
        expect(UserFeedback.active).not_to include(deleted)
      end
    end

    describe ".deleted" do
      it "returns only deleted records" do
        active  = make_feedback(is_deleted: false)
        deleted = make_feedback(is_deleted: true)

        expect(UserFeedback.deleted).to include(deleted)
        expect(UserFeedback.deleted).not_to include(active)
      end
    end

    # -------------------------------------------------------------------------
    # .positive / .neutral / .negative
    # -------------------------------------------------------------------------
    describe ".positive" do
      it "returns only positive records" do
        positive = make_feedback(category: "positive")
        neutral  = make_feedback(category: "neutral")
        negative = make_feedback(category: "negative")

        expect(UserFeedback.positive).to include(positive)
        expect(UserFeedback.positive).not_to include(neutral, negative)
      end
    end

    describe ".neutral" do
      it "returns only neutral records" do
        positive = make_feedback(category: "positive")
        neutral  = make_feedback(category: "neutral")
        negative = make_feedback(category: "negative")

        expect(UserFeedback.neutral).to include(neutral)
        expect(UserFeedback.neutral).not_to include(positive, negative)
      end
    end

    describe ".negative" do
      it "returns only negative records" do
        positive = make_feedback(category: "positive")
        neutral  = make_feedback(category: "neutral")
        negative = make_feedback(category: "negative")

        expect(UserFeedback.negative).to include(negative)
        expect(UserFeedback.negative).not_to include(positive, neutral)
      end
    end

    # -------------------------------------------------------------------------
    # .for_user
    # -------------------------------------------------------------------------
    describe ".for_user" do
      it "returns only records for the specified user" do
        other_user = create(:user)
        own        = make_feedback(user: subject_user)
        other      = make_feedback(user: other_user)

        expect(UserFeedback.for_user(subject_user.id)).to include(own)
        expect(UserFeedback.for_user(subject_user.id)).not_to include(other)
      end
    end

    # -------------------------------------------------------------------------
    # .default_order
    # -------------------------------------------------------------------------
    describe ".default_order" do
      it "returns records newest-first" do
        older = make_feedback
        newer = make_feedback

        # Ensure distinct created_at by touching the timestamp
        older.update_columns(created_at: 1.hour.ago)

        ids = UserFeedback.default_order.ids
        expect(ids.index(newer.id)).to be < ids.index(older.id)
      end
    end

    # -------------------------------------------------------------------------
    # .visible
    # -------------------------------------------------------------------------
    describe ".visible" do
      let(:active_feedback)  { make_feedback(is_deleted: false) }
      let(:deleted_feedback) { make_feedback(is_deleted: true) }

      before do
        active_feedback
        deleted_feedback
      end

      it "returns all records (active and deleted) for staff" do
        staff = create(:janitor_user)
        expect(UserFeedback.visible(staff)).to include(active_feedback, deleted_feedback)
      end

      it "returns only active records for a regular member" do
        member = create(:user)
        expect(UserFeedback.visible(member)).to include(active_feedback)
        expect(UserFeedback.visible(member)).not_to include(deleted_feedback)
      end
    end
  end
end
