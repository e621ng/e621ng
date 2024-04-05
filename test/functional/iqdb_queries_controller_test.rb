# frozen_string_literal: true

require "test_helper"

class IqdbQueriesControllerTest < ActionDispatch::IntegrationTest
  context "The iqdb controller" do
    setup do
      Danbooru.config.stubs(:iqdb_server).returns("https://karasuma.donmai.us")
      @user = create(:user)
      as(@user) do
        @posts = create_list(:post, 2)
      end
    end

    context "show action" do
      context "with a url parameter" do
        setup do
          create(:upload_whitelist, pattern: "*google.com")
          @url = "https://google.com"
          @params = { url: @url }
          @mocked_response = [{
            "post" => @posts[0],
            "post_id" => @posts[0].id,
            "score" => 1
          }]
        end

        should "render a response" do
          IqdbProxy.expects(:query_url).with(@url, nil).returns(@mocked_response)
          get_auth iqdb_queries_path, @user, params: @params
          assert_select("#post_#{@posts[0].id}")
        end
      end

      context "with a post_id parameter" do
        setup do
          @params = { post_id: @posts[0].id }
          @url = @posts[0].preview_file_url
          @mocked_response = [{
            "post" => @posts[0],
            "post_id" => @posts[0].id,
            "score" => 1
          }]
        end

        should "redirect to iqdb" do
          IqdbProxy.expects(:query_post).with(@posts[0], nil).returns(@mocked_response)
          get_auth iqdb_queries_path, @user, params: @params
          assert_select("#post_#{@posts[0].id}")
        end
      end

      context "with matches" do
        setup do
          json = @posts.map { |x| { "post_id" => x.id, "score" => 1 } }.to_json
          @params = { matches: json }
        end

        should "render with matches" do
          get_auth iqdb_queries_path, @user, params: @params
          assert_response :success
        end
      end
    end
  end
end
