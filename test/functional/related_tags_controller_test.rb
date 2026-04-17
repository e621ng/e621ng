# frozen_string_literal: true

require "test_helper"

class RelatedTagsControllerTest < ActionDispatch::IntegrationTest
  context "The related tags controller" do
    context "show action" do
      should "work" do
        get_auth related_tag_path, create(:user), params: { query: "touhou" }
        assert_response :success
      end

      should "return 422 instead of 500 when too many tags are searched" do
        query = (1..(Danbooru.config.tag_query_limit + 1)).map { |i| "tag_#{i}" }.join(" ")
        get_auth related_tag_path, create(:user), params: { search: { query: query, category_id: Tag.categories.general } }
        assert_response 422
      end
    end
  end
end
