# frozen_string_literal: true

require "test_helper"

class HelpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    as(@user) do
      @wiki = create(:wiki_page, title: "help")
    end
  end

  test "index renders" do
    @help = HelpPage.create!(wiki_page: @wiki.title, name: "very_important")

    get help_pages_path
    assert_response :success
  end

  test "index renders for admins" do
    @help = HelpPage.create!(wiki_page: @wiki.title, name: "very_important")

    get_auth help_pages_path, create(:admin_user)
    assert_response :success
  end

  test "it loads when the url contains spaces" do
    @help = HelpPage.create!(wiki_page: @wiki.title, name: "very_important")

    get help_page_path(id: "very important")
    assert_response :success
  end
end
