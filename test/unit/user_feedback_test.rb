require 'test_helper'

class UserFeedbackTest < ActiveSupport::TestCase
  context "A user's feedback" do
    setup do
      CurrentUser.ip_addr = "127.0.0.1"
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    should "create a dmail" do
      user = FactoryBot.create(:user)
      privileged = FactoryBot.create(:privileged_user)
      member = FactoryBot.create(:user)

      dmail = <<~EOS.chomp
        @#{privileged.name} created a "positive record":/user_feedbacks?search[user_id]=#{user.id} for your account:

        good job!
      EOS

      CurrentUser.user = privileged
      assert_difference("Dmail.count", 1) do
        FactoryBot.create(:user_feedback, :user => user, :body => "good job!")
        assert_equal(dmail, user.dmails.last.body)
      end
    end

    should "not validate if the creator is the user" do
      privileged_user = FactoryBot.create(:privileged_user)
      CurrentUser.user = privileged_user
      feedback = FactoryBot.build(:user_feedback, :user => privileged_user)
      feedback.save
      assert_equal(["You cannot submit feedback for yourself"], feedback.errors.full_messages)
    end

    context "with a no_feedback user" do
      setup do
        @privileged_user = FactoryBot.create(:privileged_user, no_feedback: true)
        CurrentUser.user = @privileged_user
      end

      should "not validate" do
        feedback = FactoryBot.build(:user_feedback, :user => @privileged_user)
        feedback.save
        assert_equal(["You cannot submit feedback"], feedback.errors.full_messages.grep(/^You cannot submit feedback$/))
      end
    end

    should "not validate if the creator is not gold" do
      user = FactoryBot.create(:user)
      privileged = FactoryBot.create(:privileged_user)
      member = FactoryBot.create(:user)

      CurrentUser.user = privileged
      feedback = FactoryBot.create(:user_feedback, :user => user)
      assert(feedback.errors.empty?)

      CurrentUser.user = member
      feedback = FactoryBot.build(:user_feedback, :user => user)
      feedback.save
      assert_equal(["You must be gold"], feedback.errors.full_messages)
    end
  end
end
