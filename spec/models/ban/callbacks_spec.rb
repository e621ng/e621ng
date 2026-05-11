# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                            Ban Callbacks                                    #
# --------------------------------------------------------------------------- #

RSpec.describe Ban do
  let(:moderator)    { create(:moderator_user) }
  let(:subject_user) { create(:user) }

  before { CurrentUser.user = moderator }
  after  { CurrentUser.user = nil }

  describe "callbacks" do
    # -------------------------------------------------------------------------
    # after_create: update_user_on_create
    # -------------------------------------------------------------------------
    describe "after_create: update_user_on_create" do
      it "marks the user as banned" do
        expect do
          create(:ban, user: subject_user, banner: moderator)
        end.to change { subject_user.reload.is_banned }.from(false).to(true)
      end

      it "sets the user level to BLOCKED" do
        expect do
          create(:ban, user: subject_user, banner: moderator)
        end.to change { subject_user.reload.level }.to(User::Levels::BLOCKED)
      end
    end

    # -------------------------------------------------------------------------
    # after_create: create_feedback
    # -------------------------------------------------------------------------
    describe "after_create: create_feedback" do
      it "creates a negative feedback record for the banned user" do
        expect do
          create(:ban, user: subject_user, banner: moderator)
        end.to change { subject_user.feedback.negative.count }.by(1)
      end

      it "includes the ban reason in the feedback body" do
        create(:ban, user: subject_user, banner: moderator, reason: "spamming the forum")
        fb = subject_user.feedback.negative.last
        expect(fb.body).to include("spamming the forum")
      end

      it "mentions the ban is permanent in the feedback body for permanent bans" do
        create(:permaban, user: subject_user, banner: moderator)
        fb = subject_user.feedback.negative.last
        expect(fb.body).to include("permanently")
      end

      it "mentions the duration in the feedback body for timed bans" do
        create(:ban, user: subject_user, banner: moderator, duration: 7)
        fb = subject_user.feedback.negative.last
        expect(fb.body).to include("for")
      end
    end

    # -------------------------------------------------------------------------
    # after_destroy: update_user_on_destroy
    # -------------------------------------------------------------------------
    describe "after_destroy: update_user_on_destroy" do
      it "clears the is_banned flag on the user" do
        ban = create(:ban, user: subject_user, banner: moderator)
        expect do
          ban.destroy!
        end.to change { subject_user.reload.is_banned }.from(true).to(false)
      end

      it "restores the user level to MEMBER" do
        ban = create(:ban, user: subject_user, banner: moderator)
        expect do
          ban.destroy!
        end.to change { subject_user.reload.level }.to(User::Levels::MEMBER)
      end
    end
  end
end
