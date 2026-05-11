# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         UserFeedback Instance Methods                       #
# --------------------------------------------------------------------------- #

RSpec.describe UserFeedback do
  subject(:feedback) { create(:user_feedback, user: subject_user, creator: moderator) }

  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  # -------------------------------------------------------------------------
  # Methods
  # -------------------------------------------------------------------------
  describe "methods" do
    # -------------------------------------------------------------------------
    # #user_name
    # -------------------------------------------------------------------------
    describe "#user_name" do
      it "returns the name of the subject user" do
        expect(feedback.user_name).to eq(subject_user.name)
      end
    end

    # -------------------------------------------------------------------------
    # #user_name=
    # -------------------------------------------------------------------------
    describe "#user_name=" do
      it "assigns user_id by looking up the name" do
        other = create(:user)
        feedback.user_name = other.name
        expect(feedback.user_id).to eq(other.id)
      end

      it "sets user_id to nil for a name that does not exist" do
        feedback.user_name = "nonexistent_user_xyz"
        expect(feedback.user_id).to be_nil
      end
    end

    # -------------------------------------------------------------------------
    # #editable_by?
    # -------------------------------------------------------------------------
    describe "#editable_by?" do
      it "returns true for a moderator who is not the subject user" do
        editor = create(:moderator_user)
        expect(feedback.editable_by?(editor)).to be(true)
      end

      it "returns false for a regular member" do
        member = create(:user)
        expect(feedback.editable_by?(member)).to be(false)
      end

      it "returns false when the editor is the subject user, even if moderator" do
        # Make the moderator also the subject of their own feedback record
        create(:user_feedback, user: create(:user), creator: moderator)
        # Rebuild a feedback where the editor IS the subject
        target = create(:user_feedback, user: moderator, creator: create(:moderator_user))
        expect(target.editable_by?(moderator)).to be(false)
      end
    end

    # -------------------------------------------------------------------------
    # #deletable_by?
    # -------------------------------------------------------------------------
    describe "#deletable_by?" do
      it "returns true for a moderator who is not the subject user" do
        deleter = create(:moderator_user)
        expect(feedback.deletable_by?(deleter)).to be(true)
      end

      it "returns false for a regular member" do
        member = create(:user)
        expect(feedback.deletable_by?(member)).to be(false)
      end

      it "behaves identically to editable_by?" do
        editor = create(:moderator_user)
        expect(feedback.deletable_by?(editor)).to eq(feedback.editable_by?(editor))
      end
    end

    # -------------------------------------------------------------------------
    # #destroyable_by?
    # -------------------------------------------------------------------------
    describe "#destroyable_by?" do
      it "returns true for an admin who is not the subject user" do
        admin = create(:admin_user)
        expect(feedback.destroyable_by?(admin)).to be(true)
      end

      it "returns true for the original creator (moderator, not subject)" do
        expect(feedback.destroyable_by?(moderator)).to be(true)
      end

      it "returns false for a moderator who is neither the creator nor an admin" do
        other_moderator = create(:moderator_user)
        expect(feedback.destroyable_by?(other_moderator)).to be(false)
      end

      it "returns false for a regular member" do
        member = create(:user)
        expect(feedback.destroyable_by?(member)).to be(false)
      end

      it "returns false when the destroyer is the subject user, even if admin" do
        # Admin who is also the feedback subject cannot destroy (editable_by? is false)
        admin = create(:admin_user)
        target = create(:user_feedback, user: admin, creator: moderator)
        expect(target.destroyable_by?(admin)).to be(false)
      end
    end
  end
end
