require 'test_helper'

class UserNameChangeRequestTest < ActiveSupport::TestCase
  context "in all cases" do
    setup do
      @admin = create(:admin_user)
      @requester = create(:user)
      CurrentUser.user = @requester
    end

    context "approving a request" do
      setup do
        @change_request = UserNameChangeRequest.create(
          :user_id => @requester.id,
          :original_name => @requester.name,
          :status => "pending",
          :desired_name => "abc"
        )
        CurrentUser.user = @admin
      end

      should "create a dmail" do
        assert_difference("Dmail.count", 1) do
          @change_request.approve!
        end
      end

      should "change the user's name" do
        @change_request.approve!
        @requester.reload
        assert_equal("abc", @requester.name)
      end

      should "clear the user name cache" do
        @change_request.approve!
        assert_equal("abc", Cache.get("uin:#{@requester.id}"))
      end

      should "create mod action" do
        assert_difference("ModAction.count", 1) do
          @change_request.approve!
        end
      end
    end

    context "creating a new request" do
      should "not validate if the desired name already exists" do
        assert_difference("UserNameChangeRequest.count", 0) do
          req = UserNameChangeRequest.create(
            :user_id => @requester.id,
            :original_name => @requester.name,
            :status => "pending",
            :desired_name => @requester.name
          )
          assert_equal(["Desired name already exists"], req.errors.full_messages)
        end
      end

      should "not convert the desired name to lower case" do
        uncr = create(:user_name_change_request, user: @requester, original_name: "provence.", desired_name: "Provence")
        as(@admin) { uncr.approve! }

        assert_equal("Provence", @requester.name)
      end
    end
  end
end
