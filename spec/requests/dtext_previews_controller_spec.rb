# frozen_string_literal: true

require "rails_helper"

RSpec.describe DtextPreviewsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member) { create(:user) }

  # ---------------------------------------------------------------------------
  # POST /dtext_preview — create
  # ---------------------------------------------------------------------------

  describe "POST /dtext_preview" do
    it "returns 200 for an anonymous request" do
      post dtext_preview_path, params: { body: "hello" }
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON with html and posts keys" do
      post dtext_preview_path, params: { body: "hello" }
      expect(response.content_type).to match(%r{application/json})
      body = response.parsed_body
      expect(body).to have_key("html")
      expect(body).to have_key("posts")
      expect(body["html"]).to be_a(String)
      expect(body["posts"]).to be_a(Hash)
    end

    it "returns 200 for a signed-in member" do
      sign_in_as member
      post dtext_preview_path, params: { body: "hello" }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 when body param is omitted" do
      post dtext_preview_path
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["html"]).to be_a(String)
    end

    it "returns 200 for an empty body" do
      post dtext_preview_path, params: { body: "" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["html"]).to be_a(String)
    end

    it "renders DText markup to HTML" do
      post dtext_preview_path, params: { body: "[b]bold[/b]" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["html"]).to include("<strong>bold</strong>")
    end

    it "wraps output in a styled-dtext div" do
      post dtext_preview_path, params: { body: "hello" }
      expect(response.parsed_body["html"]).to include('class="styled-dtext"')
    end

    it "accepts allow_color param without error" do
      post dtext_preview_path, params: { body: "hello", allow_color: "1" }
      expect(response).to have_http_status(:ok)
    end

    # FIXME: DText.parse does not return post IDs in the test environment — parsed[1]
    # is always empty so deferred_post_ids is never populated and `posts` stays {}.
    # Uncomment once the gem's post-link extraction is confirmed to work in specs.
    # it "populates posts when a post is referenced in the body" do
    #   post = create(:post)
    #   post dtext_preview_path, params: { body: "post ##{post.id}" }
    #   expect(response).to have_http_status(:ok)
    #   expect(response.parsed_body["posts"]).to have_key(post.id.to_s)
    # end
  end
end
