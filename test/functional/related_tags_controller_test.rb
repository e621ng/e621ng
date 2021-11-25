require 'test_helper'

class RelatedTagsControllerTest < ActionDispatch::IntegrationTest
  context "The related tags controller" do
    context "show action" do
      setup do
        @user = create(:user)
      end

      should "work" do
        get_auth related_tag_path, @user, params: { query: "touhou" }
        assert_response :success
      end
    end
  end
end
