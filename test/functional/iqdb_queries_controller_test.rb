# frozen_string_literal: true

require "test_helper"

class IqdbQueriesControllerTest < ActionDispatch::IntegrationTest
  context "The iqdb controller" do
    setup do
      IqdbProxy.stubs(:endpoint).returns("http://iqdb:5588")
      CloudflareService.stubs(:ips).returns([])
    end

    context "show action" do
      context "with a url parameter" do
        should "render a response" do
          post = create(:post)
          create(:upload_whitelist, domain: "google.com")
          stub_request(:get, "https://google.com/foo.jpg")
            .to_return(body: file_fixture("test.jpg").read)
          response = [{ "post_id" => post.id, "score" => 80 }]
          stub_request(:post, "#{IqdbProxy.endpoint}/query").to_return_json(body: response)
          get iqdb_queries_path, params: { url: "https://google.com/foo.jpg" }

          assert_response :success
          assert_select("article.thumbnail[data-id='#{post.id}']")
        end
      end

      context "with a post_id parameter" do
        should "redirect to iqdb" do
          post = create(:post)
          response = [{ "post_id" => post.id, "score" => 80 }]
          stub_request(:post, "#{IqdbProxy.endpoint}/query").to_return_json(body: response)
          Post.any_instance.stubs(:preview_file_path).returns(file_fixture("test.jpg"))

          get iqdb_queries_path, params: { post_id: post.id }
          assert_response :success
          assert_select("article.thumbnail[data-id='#{post.id}']")
        end
      end
    end
  end
end
