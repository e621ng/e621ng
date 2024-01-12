require 'test_helper'

class UserFeedbackTest < ActiveSupport::TestCase
  context "A user's feedback" do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @admin = create(:admin_user)
      CurrentUser.user = @mod
    end

    should "create a dmail" do
      dmail = <<~DMAIL.chomp
        #{@mod.name} created a "positive record":/user_feedbacks?search[user_id]=#{@user.id} for your account:

        good job!
      DMAIL
      assert_difference("Dmail.count", 1) do
        create(:user_feedback, user: @user, body: "good job!")
        assert_equal(dmail, @user.dmails.first.body)
      end
    end

    should "correctly credit the updater" do
      feedback = create(:user_feedback, user: @user, body: "good job!")

      dmail = <<~DMAIL.chomp
        #{@admin.name} updated a "positive record":/user_feedbacks?search[user_id]=#{@user.id} for your account:

        great job!
      DMAIL

      assert_difference("Dmail.count", 1) do
        CurrentUser.scoped(@admin) do
          feedback.update(body: "great job!", send_update_dmail: true)
        end
        assert_equal(dmail, @user.dmails.first.body)
      end
    end

    should "not validate if the creator is the user" do
      feedback = build(:user_feedback, user: @mod)
      feedback.save
      assert_equal(["You cannot submit feedback for yourself"], feedback.errors.full_messages)
    end

    should "not validate if the creator has no permissions" do
      privileged = create(:privileged_user)

      CurrentUser.user = privileged
      feedback = build(:user_feedback, user: @user)
      feedback.save
      assert_equal(["You must be moderator"], feedback.errors.full_messages)
    end
  end
end
