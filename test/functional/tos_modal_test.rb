# frozen_string_literal: true

require "test_helper"

class TosModalTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create(:user)
    @post = create(:post)
  end

  def shows_tos_modal
    assert_select "#tos-form"
  end

  def does_not_show_tos_modal
    assert_select "#tos-form", false
  end

  context "A new user" do
    should "see the TOS modal on protected pages" do
      get post_path(@post)
      shows_tos_modal
    end

    should "not see the TOS modal on the terms of service page" do
      get static_terms_of_service_path
      does_not_show_tos_modal
    end

    should "not see the TOS modal on the privacy policy page" do
      get static_privacy_path
      does_not_show_tos_modal
    end

    should "not see the TOS modal on the rules page" do
      get static_rules_path
      does_not_show_tos_modal
    end

    should "not see the TOS modal on the api page" do
      get static_api_path
      does_not_show_tos_modal
    end
  end
end
