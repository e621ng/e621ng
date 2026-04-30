# frozen_string_literal: true

require "test_helper"

class UserPasswordResetNonceTest < ActiveSupport::TestCase
  context "Creating a new nonce" do
    setup do
      @user = create(:user)
      @nonce = create(:user_password_reset_nonce, user: @user)
    end

    should "validate" do
      assert_equal([], @nonce.errors.full_messages)
    end

    should "populate the key with a random string" do
      assert_equal(24, @nonce.key.size)
    end

    should "reset the password when reset" do
      @nonce.reset_user! "test", "test"
      assert User.authenticate(@user.name, "test")
    end
  end
end
