require "test_helper"

class RecommendedPostsControllerTest < ActionDispatch::IntegrationTest
  context "The recommended posts controller" do
    setup do
      @user = travel_to(1.month.ago) {create(:user)}
      as_user do
        @post = create(:post, :tag_string => "aaaa")
      end
      RecommenderService.stubs(:enabled?).returns(true)
    end

    context "post context" do
      setup do
        RecommenderService.stubs(:available_for_post?).returns(true)
        RecommenderService.stubs(:recommend_for_post).returns([@post])
      end

      should "render" do
        get_auth recommended_posts_path, @user, xhr: true, params: {context: "post", post_id: @post.id}
        assert_response :success
        assert_select ".recommended-posts"
        assert_select ".recommended-posts #post_#{@post.id}"
      end
    end

    context "user context" do
      setup do
        RecommenderService.stubs(:available_for_user?).returns(true)
        RecommenderService.stubs(:recommend_for_user).returns([@post])
      end

      should "render" do
        get_auth recommended_posts_path, @user, params: {context: "user"}
        assert_response :success
        assert_select ".recommended-posts"
        assert_select ".recommended-posts #post_#{@post.id}"
      end
    end
  end
end
