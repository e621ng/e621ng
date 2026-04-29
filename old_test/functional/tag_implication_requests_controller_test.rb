# frozen_string_literal: true

require "test_helper"

class TagImplicationRequestsControllerTest < ActionDispatch::IntegrationTest
  context "The tag implication request controller" do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    context "new action" do
      should "render" do
        get_auth new_tag_implication_request_path, @user
        assert_response :success
      end
    end

    context "create action" do
      should "create forum post" do
        assert_difference("ForumTopic.count", 1) do
          post_auth tag_implication_request_path, @user, params: { tag_implication_request: { antecedent_name: "aaa", consequent_name: "bbb", reason: "ccccc" } }
        end
        assert_redirected_to(forum_topic_path(ForumTopic.last))
      end

      should "create a pending implication" do
        params = {
          :tag_implication_request => {
            :antecedent_name => "foo",
            :consequent_name => "bar",
            :reason => "blah blah"
          }
        }

        assert_difference("ForumTopic.count") do
          post_auth tag_implication_request_path, @user, params: params
        end
        assert_redirected_to(forum_topic_path(ForumTopic.last))
      end
    end
  end
end
