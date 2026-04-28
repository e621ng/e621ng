# frozen_string_literal: true

require "test_helper"

class AutomodUserCheckJobTest < ActiveJob::TestCase
  context "AutomodUserCheckJob" do
    setup do
      @admin = create(:admin_user)
      CurrentUser.user = @admin
      @user = create(:user, name: "normaluser")
    end

    teardown do
      CurrentUser.user = nil
    end

    context "username checks" do
      should "create a ticket when the username matches a usernames rule" do
        rule = create(:automod_rule, :for_usernames, regex: "badword")
        @user.update_columns(name: "badworduser")
        assert_difference("Ticket.count", 1) do
          AutomodUserCheckJob.perform_now(@user.id, check_username: true, check_profile: false)
        end
        ticket = Ticket.last
        assert_equal("user", ticket.qtype)
        assert_equal(@user.id, ticket.disp_id)
        assert_match(rule.name, ticket.reason)
      end

      should "not create a ticket when the username does not match" do
        create(:automod_rule, :for_usernames, regex: "badword")
        assert_no_difference("Ticket.count") do
          AutomodUserCheckJob.perform_now(@user.id, check_username: true, check_profile: false)
        end
      end

      should "not create a ticket when the matching rule is comments-only" do
        create(:automod_rule, :for_comments, regex: "normaluser")
        assert_no_difference("Ticket.count") do
          AutomodUserCheckJob.perform_now(@user.id, check_username: true, check_profile: false)
        end
      end
    end

    context "profile text checks" do
      should "create a ticket when profile_about matches a profile_text rule" do
        create(:automod_rule, :for_profile_text, regex: "badcontent")
        @user.update_columns(profile_about: "this is badcontent")
        assert_difference("Ticket.count", 1) do
          AutomodUserCheckJob.perform_now(@user.id, check_username: false, check_profile: true)
        end
        assert_equal("user", Ticket.last.qtype)
      end

      should "create a ticket when profile_artinfo matches a profile_text rule" do
        create(:automod_rule, :for_profile_text, regex: "badcontent")
        @user.update_columns(profile_artinfo: "this is badcontent")
        assert_difference("Ticket.count", 1) do
          AutomodUserCheckJob.perform_now(@user.id, check_username: false, check_profile: true)
        end
      end

      should "not create a ticket when the matching rule is comments-only" do
        create(:automod_rule, :for_comments, regex: "normaluser")
        @user.update_columns(profile_about: "normaluser profile")
        assert_no_difference("Ticket.count") do
          AutomodUserCheckJob.perform_now(@user.id, check_username: false, check_profile: true)
        end
      end
    end

    context "stopping at first match" do
      should "not check profile text when the username already matched" do
        username_rule = create(:automod_rule, :for_usernames, regex: "badword")
        create(:automod_rule, :for_profile_text, regex: "also_bad")
        @user.update_columns(name: "badworduser", profile_about: "also_bad content")
        assert_difference("Ticket.count", 1) do
          AutomodUserCheckJob.perform_now(@user.id, check_username: true, check_profile: true)
        end
        assert_match(username_rule.name, Ticket.last.reason)
      end
    end

    context "duplicate ticket prevention" do
      should "not create a ticket when an active user ticket already exists" do
        create(:automod_rule, :for_usernames, regex: "badword")
        @user.update_columns(name: "badworduser")
        CurrentUser.as_system do
          Ticket.create!(creator_id: User.system.id, creator_ip_addr: "127.0.0.1",
                         disp_id: @user.id, status: "pending", qtype: "user", reason: "existing")
        end
        assert_no_difference("Ticket.count") do
          AutomodUserCheckJob.perform_now(@user.id, check_username: true, check_profile: false)
        end
      end
    end

    context "error handling" do
      should "handle a deleted user gracefully" do
        user_id = @user.id
        @user.destroy
        assert_nothing_raised do
          AutomodUserCheckJob.perform_now(user_id, check_username: true, check_profile: false)
        end
      end
    end
  end
end
