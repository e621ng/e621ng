# frozen_string_literal: true

require "test_helper"

class RelatedTagsControllerTest < ActionDispatch::IntegrationTest
  context "The related tags controller" do
    context "show action" do
      should "work" do
        get_auth related_tag_path, create(:user), params: { query: "touhou" }
        assert_response :success
      end
    end
  end
end
