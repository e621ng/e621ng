# frozen_string_literal: true

require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  context "in all cases a user" do
    setup do
      @user = create(:privileged_user, name: "abcdef")
      @api_key = ApiKey.generate!(@user, name: "test")
    end

    should "regenerate the key" do
      assert_changes(-> { @api_key.key }) do
        @api_key.regenerate!
      end
    end

    should "generate a unique key" do
      assert_not_nil(@api_key.key)
    end

    should "authenticate via api key" do
      user, key = User.authenticate_api_key(@user.name, @api_key.key)
      assert_not_nil(user)
      assert_not_nil(key)
    end

    should "not authenticate with the wrong api key" do
      assert_nil(User.authenticate_api_key(@user.name, "xxx"))
    end

    should "not authenticate with the wrong name" do
      assert_nil(User.authenticate_api_key("xxx", @api_key.key))
    end

    should "have the same limits whether or not they have an api key" do
      assert_no_difference(["@user.reload.api_regen_multiplier", "@user.reload.api_burst_limit"]) do
        @api_key.destroy
      end
    end
  end
end
