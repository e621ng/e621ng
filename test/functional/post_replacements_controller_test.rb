require 'test_helper'

class PostReplacementsControllerTest < ActionDispatch::IntegrationTest

  setup do
    Sidekiq::Testing::inline!
  end

  teardown do
    Sidekiq::Testing::fake!
  end

  context "The post replacements controller" do
    setup do
      @user = create(:moderator_user, can_approve_posts: true, created_at: 1.month.ago)
      @user.as_current do
        @post = create(:post, source: "https://google.com")
      end
    end

    context "create action" do
      should "accept new non duplicate replacement" do
        file = Rack::Test::UploadedFile.new("#{Rails.root}/test/files/test.jpg", "image/jpeg")
        params = {
          post_id: @post.id,
          post_replacement: {
            replacement_file: file,
            reason: 'test replacement'
          }
        }

        assert_difference(-> { @post.replacements.size }) do
          post_auth post_replacements_path, @user, params: params
          @post.reload
        end

        # travel_to(Time.now + PostReplacement::DELETION_GRACE_PERIOD + 1.day) do
        #   Delayed::Worker.new.work_off
        # end

        assert_redirected_to post_path(@post)
      end
    end

    context "index action" do
      should "render" do
        get post_replacements_path
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get_auth new_post_replacement_path, @user, params: {post_id: @post.id}
        assert_response :success
      end
    end
  end
end
