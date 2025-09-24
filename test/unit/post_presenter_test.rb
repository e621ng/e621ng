# frozen_string_literal: true

require "test_helper"

class PostPresenterTest < ActiveSupport::TestCase
  context "PostPresenter" do
    setup do
      CurrentUser.user = create(:mod_user)

      create(:tag, name: "bkub", category: Tag.categories.artist)
      create(:tag, name: "chen", category: Tag.categories.character)
      create(:tag, name: "cirno", category: Tag.categories.character)
      create(:tag, name: "solo", category: Tag.categories.general)
      create(:tag, name: "touhou", category: Tag.categories.copyright)

      @post = create(:post, uploader_id: CurrentUser.user.id, tag_string: "bkub chen cirno solo touhou")
    end

    context "#split_tag_list_text method" do
      should "list all categories in order" do
        text = @post.presenter.categorized_tag_list_text
        assert_equal("bkub \ntouhou \nchen cirno \nsolo", text)
      end

      should "skip empty categories" do
        @post.update(tag_string: "bkub solo")
        @post.reload
        text = @post.presenter.categorized_tag_list_text
        assert_equal("bkub \nsolo", text)
      end
    end
  end
end
