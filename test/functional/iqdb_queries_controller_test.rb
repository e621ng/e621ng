require 'test_helper'

class IqdbQueriesControllerTest < ActionDispatch::IntegrationTest
  context "The iqdb controller" do
    setup do
      Danbooru.config.stubs(:iqdbs_server).returns("https://karasuma.donmai.us")
      @user = create(:user, created_at: 2.weeks.ago)
      @upload = UploadService.new(FactoryBot.attributes_for(:jpg_upload).merge(uploader: @user, uploader_ip_addr: '127.0.0.1')).start!
      @post = @upload.post
    end

    context "show action" do
      context "with a url parameter" do
        setup do
          FactoryBot.create(:upload_whitelist, pattern: "*google.com*")
          @url = "https://google.com"
          @params = { url: @url }
          @mocked_response = [{
            "post" => @post,
            "post_id" => @post.id,
            "score" => 1
          }]
        end

        should "render a response" do
          IqdbProxy.expects(:query).with(@url).returns(@mocked_response)
          get_auth iqdb_queries_path(variant: "xhr"), @user, params: @params
          assert_select("#post_#{@post.id}")
        end
      end

      context "with a post_id parameter" do
        setup do
          @params = { post_id: @post.id }
          @path = @post.preview_file_path
          @mocked_response = [{
            "post" => @post,
            "post_id" => @post.id,
            "score" => 1
          }]
        end

        should "redirect to iqdbs" do
          IqdbProxy.expects(:query_path).with(@path).returns(@mocked_response)
          get_auth iqdb_queries_path, @user, params: @params
          assert_select("#post_#{@post.id}")
        end
      end
    end
  end
end
