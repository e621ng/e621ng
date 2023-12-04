require "test_helper"

module DocumentStore
  class ModelTest < ActiveSupport::TestCase
    setup do
      WebMock.disable_net_connect!
      WebMock.reset_executed_requests!
    end

    teardown do
      WebMock.disable_net_connect!(allow: [Danbooru.config.opensearch_host])
    end

    def stub_opensearch(method, path)
      stub_request(method, "http://#{Danbooru.config.opensearch_host}:9200#{path}")
    end

    test "it deletes the index" do
      delete_request = stub_opensearch(:delete, "/posts_test")
      Post.document_store.delete_index!
      assert_requested delete_request
    end

    test "it checks for the existance of the index" do
      head_request = stub_opensearch(:head, "/posts_test")
      Post.document_store.index_exist?
      assert_requested head_request
    end

    test "it skips creating the index if it already exists" do
      head_request = stub_opensearch(:head, "/posts_test").to_return(status: 200)
      Post.document_store.create_index!
      assert_requested head_request
    end

    test "it creates the index if it doesn't exist" do
      head_request = stub_opensearch(:head, "/posts_test").to_return(status: 404)
      put_request = stub_opensearch(:put, "/posts_test").with(body: Post.document_store.index)
      assert(Post.document_store.index.present?)

      Post.document_store.create_index!

      assert_requested(head_request)
      assert_requested(put_request)
    end

    test "it recreates the index if delete_existing is true and the index already exists" do
      head_request = stub_opensearch(:head, "/posts_test").to_return(status: 200)
      delete_request = stub_opensearch(:delete, "/posts_test")
      put_request = stub_opensearch(:put, "/posts_test")

      Post.document_store.create_index!(delete_existing: true)

      assert_requested(head_request)
      assert_requested(delete_request)
      assert_requested(put_request)
    end

    test "it deletes by query" do
      post_request = stub_opensearch(:post, "/posts_test/_delete_by_query?q=*").with(body: "{}")
      Post.document_store.delete_by_query(query: "*", body: {})
      assert_requested(post_request)
    end

    test "it refreshes the index" do
      post_request = stub_opensearch(:post, "/posts_test/_refresh")
      Post.document_store.refresh_index!
      assert_requested(post_request)
    end

    test "models share the same client" do
      assert_equal(Post.document_store.client.object_id, PostVersion.document_store.client.object_id)
    end
  end
end
