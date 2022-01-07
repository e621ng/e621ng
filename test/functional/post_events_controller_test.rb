require 'test_helper'

class PostEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to(2.weeks.ago) do
      @user1 = create(:user)
      @user2 = create(:user)
      @user3 = create(:user)
      @janitor = create(:janitor_user)
    end

    as(@user1) do
      @post1 = create(:post, uploader: @user1)
      create(:post_flag, post: @post1)
    end
    as(@user2) do
      @post2 = create(:post, uploader: @user2)
      create(:post_flag, post: @post2)
      @post3 = create(:post, uploader: @user2)
      create(:post_flag, post: @post3)
    end
  end

  context "index" do
    should "render" do
      get_auth post_events_path, @user1
      assert_response :ok
    end
  end

  context "searching" do
    should "only return your own flags as a normal  user" do
      get_auth post_events_path(search: { creator_id: @user1.id }), @user1
      assert_select "table tbody tr", 1
      get_auth post_events_path(search: { creator_id: @user1.id }), @user2
      assert_select "table tbody tr", 0
    end

    should "hide the creator for flags" do
      get_auth post_events_path(search: { action: "flag_created" }), @user1
      assert_select "table tbody tr", 3
      assert_select "table tbody tr", { count: 2, text: /hidden/ }
      get_auth post_events_path(search: { action: "flag_created" }), @user3
      assert_select "table tbody tr", { count: 3, text: /hidden/ }
    end

    should "show everything for janitors" do
      get_auth post_events_path(search: { creator_id: @user2.id }), @janitor
      assert_select "table tbody tr", 2
      get_auth post_events_path(search: { action: "flag_created" }), @janitor
      assert_select "table tbody tr", { count: 0, text: /hidden/ }
    end
  end

  context "get /post_events.json" do
    context "for the creator of a flag" do
      setup do
        get_auth post_events_path, @user1, params: { format: :json }
        @json = JSON.parse(response.body)
        @flag_actions = @json.select { |e| e["action"] == "flag_created" }
      end

      should "expose themselves as the flagger" do
        assert_equal 1, @flag_actions.reject { |action| action["creator_id"].nil? }.count
      end
    end

    context "for a normal user" do
      setup do
        get_auth post_events_path, @user3, params: { format: :json }
        @flag_actions = JSON.parse(response.body)
      end

      should "hide all flaggers" do
        assert_equal 0, @flag_actions.reject { |action| action["creator_id"].nil? }.count
      end
    end

    context "for janitors" do
      setup do
        get_auth post_events_path, @janitor, params: { format: :json }
        @flag_actions = JSON.parse(response.body)
      end

      should "show all flaggers" do
        assert_equal 3, @flag_actions.reject { |action| action["creator_id"].nil? }.count
      end
    end
  end
end
