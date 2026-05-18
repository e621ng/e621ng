# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          UserFeedback Validations                           #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  # -------------------------------------------------------------------------
  # Validations
  # -------------------------------------------------------------------------
  describe "validations" do
    # -------------------------------------------------------------------------
    # body
    # -------------------------------------------------------------------------
    describe "body" do
      it "is invalid without a body" do
        feedback = build(:user_feedback, body: nil)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:body]).to include("can't be blank")
      end

      it "is invalid with a blank body" do
        feedback = build(:user_feedback, body: "")
        expect(feedback).not_to be_valid
        expect(feedback.errors[:body]).to include("can't be blank")
      end

      it "is invalid when exceeding the configured maximum" do
        feedback = build(:user_feedback, body: "a" * (Danbooru.config.user_feedback_max_size + 1))
        expect(feedback).not_to be_valid
        expect(feedback.errors[:body]).to be_present
      end

      it "is valid at exactly the configured maximum" do
        feedback = build(:user_feedback, body: "a" * Danbooru.config.user_feedback_max_size)
        expect(feedback).to be_valid
      end

      it "normalizes \\r\\n line endings to \\n" do
        feedback = create(:user_feedback, user: subject_user, body: "line one\r\nline two")
        expect(feedback.body).to eq("line one\nline two")
      end
    end

    # -------------------------------------------------------------------------
    # category
    # -------------------------------------------------------------------------
    describe "category" do
      it "is invalid without a category" do
        feedback = build(:user_feedback, category: nil)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:category]).to include("can't be blank")
      end

      it "is invalid with an unrecognised category" do
        feedback = build(:user_feedback, category: "excellent")
        expect(feedback).not_to be_valid
        expect(feedback.errors[:category]).to be_present
      end

      it "is valid for each accepted category" do
        %w[positive negative neutral].each do |cat|
          feedback = build(:user_feedback, category: cat)
          expect(feedback).to be_valid, "expected '#{cat}' to be valid: #{feedback.errors.full_messages.join(', ')}"
        end
      end
    end

    # -------------------------------------------------------------------------
    # creator_is_moderator (on: :create)
    # -------------------------------------------------------------------------
    describe "creator_is_moderator (on create)" do
      it "is invalid when the creator is a regular member" do
        member = create(:user)
        feedback = build(:user_feedback, user: subject_user, creator: member)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:creator]).to include("must be moderator")
      end

      it "is invalid when the creator is a janitor" do
        janitor = create(:janitor_user)
        feedback = build(:user_feedback, user: subject_user, creator: janitor)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:creator]).to include("must be moderator")
      end

      it "is valid when the creator is a moderator" do
        feedback = build(:user_feedback, user: subject_user, creator: moderator)
        expect(feedback).to be_valid
      end

      it "is valid when the creator is an admin" do
        admin = create(:admin_user)
        feedback = build(:user_feedback, user: subject_user, creator: admin)
        expect(feedback).to be_valid
      end

      it "does not re-run on update" do
        feedback = create(:user_feedback, user: subject_user, creator: moderator)
        # Demote the creator to member — creator_is_moderator should not re-fire
        moderator.update_columns(level: User::Levels::MEMBER)
        moderator.reload
        feedback.body = "updated body"
        expect(feedback).to be_valid
      end
    end

    # -------------------------------------------------------------------------
    # user_is_not_creator
    # -------------------------------------------------------------------------
    describe "user_is_not_creator" do
      it "is invalid when the subject user and creator are the same person" do
        feedback = build(:user_feedback, user: moderator, creator: moderator)
        expect(feedback).not_to be_valid
        expect(feedback.errors[:creator]).to include("cannot submit feedback for yourself")
      end

      it "is valid when the subject user and creator are different people" do
        feedback = build(:user_feedback, user: subject_user, creator: moderator)
        expect(feedback).to be_valid
      end

      it "is also enforced on update" do
        feedback = create(:user_feedback, user: subject_user, creator: moderator)
        # Reassign the subject to the creator after creation
        feedback.user = moderator
        expect(feedback).not_to be_valid
        expect(feedback.errors[:creator]).to include("cannot submit feedback for yourself")
      end
    end
  end
end
