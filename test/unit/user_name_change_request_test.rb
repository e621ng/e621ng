# frozen_string_literal: true

require "test_helper"

class UserNameChangeRequestTest < ActiveSupport::TestCase
  context "UserNameChangeRequest" do
    setup do
      @user = create(:user, name: "originalname")
      CurrentUser.user = @user
    end

    context "on creation" do
      should "automatically apply the name change" do
        assert_difference(-> { UserNameChangeRequest.count }, 1) do
          UserNameChangeRequest.create(desired_name: "newname")
        end

        @user.reload
        assert_equal("newname", @user.name)
      end

      should "initialize attributes correctly" do
        request = UserNameChangeRequest.new(desired_name: "testname")
        assert_equal(@user.id, request.user_id)
        assert_equal(@user.name, request.original_name)
      end

      should "record the original and desired names" do
        request = UserNameChangeRequest.create(desired_name: "newname")
        assert_equal("originalname", request.original_name)
        assert_equal("newname", request.desired_name)
        assert_equal(@user.id, request.user_id)
      end

      should "clear the user name cache" do
        UserNameChangeRequest.create(desired_name: "newname")
        assert_equal("newname", Cache.fetch("uin:#{@user.id}"))
      end
    end

    context "validation" do
      should "reject invalid desired names" do
        request = UserNameChangeRequest.new(desired_name: "x")
        assert_not request.valid?
        assert_includes request.errors[:desired_name], "must be 2 to 20 characters long"
      end

      should "reject desired names that already exist" do
        existing_user = create(:user, name: "taken")
        request = UserNameChangeRequest.new(desired_name: "taken")
        assert_not request.valid?
        assert_includes request.errors[:desired_name], "already exists"
      end

      should "allow changing capitalization of current name" do
        @user.update!(name: "testuser")
        CurrentUser.user = @user
        request = UserNameChangeRequest.create(desired_name: "TestUser")
        assert request.persisted?
        @user.reload
        assert_equal("TestUser", @user.name)
      end

      should "reject same exact name" do
        request = UserNameChangeRequest.new(desired_name: @user.name)
        assert_not request.valid?
        assert_includes request.errors[:desired_name], "is the same as your current name"
      end

      should "require presence of desired_name" do
        request = UserNameChangeRequest.new
        assert_not request.valid?
        assert_includes request.errors[:desired_name], "can't be blank"
        # original_name is auto-populated by initialize_attributes
        assert request.original_name.present?
      end
    end

    context "rate limiting" do
      should "prevent multiple requests within a week" do
        UserNameChangeRequest.create(desired_name: "firstchange")
        @user.reload

        second_request = UserNameChangeRequest.new(desired_name: "secondchange")
        assert_not second_request.valid?
        assert_includes second_request.errors[:base], "You can only submit one name change request per week"
      end

      should "allow requests when skip_limited_validation is true" do
        UserNameChangeRequest.create(desired_name: "firstchange")
        @user.reload

        second_request = UserNameChangeRequest.new(desired_name: "secondchange")
        second_request.skip_limited_validation = true
        assert second_request.valid?

        second_request.save!
        @user.reload
        assert_equal("secondchange", @user.name)
      end
    end

    context "when users switch names" do
      setup do
        @u1 = create(:user, name: "Alice")
        @u2 = create(:user, name: "Bob")

        # Fill cache with currently correct data
        User.name_to_id("alice")
        User.name_to_id("bob")
      end

      should "handle name swapping correctly" do
        # User 1 changes to temporary name
        as(@u1) { UserNameChangeRequest.create(desired_name: "temp", skip_limited_validation: true) }
        @u1.reload

        # User 2 takes User 1's old name
        as(@u2) { UserNameChangeRequest.create(desired_name: "Alice", skip_limited_validation: true) }
        @u2.reload

        # User 1 takes User 2's old name  
        as(@u1) { UserNameChangeRequest.create(desired_name: "Bob", skip_limited_validation: true) }
        @u1.reload

        assert_equal("Bob", @u1.name)
        assert_equal("Alice", @u2.name)
        assert_equal(@u1.id, User.name_to_id(@u1.name))
        assert_equal(@u2.id, User.name_to_id(@u2.name))
      end
    end

    context "search" do
      setup do
        @request1 = as(@user) { UserNameChangeRequest.create(desired_name: "newname1", skip_limited_validation: true) }
        @other_user = create(:user, name: "otheruser")
        @request2 = as(@other_user) { UserNameChangeRequest.create(desired_name: "newname2", skip_limited_validation: true) }
      end

      should "filter by original_name" do
        results = UserNameChangeRequest.search(original_name: "originalname")
        assert_includes results, @request1
        assert_not_includes results, @request2
      end

      should "filter by desired_name" do
        results = UserNameChangeRequest.search(desired_name: "newname1")
        assert_includes results, @request1
        assert_not_includes results, @request2
      end
    end
  end
end
