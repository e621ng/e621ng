# frozen_string_literal: true

require "rails_helper"

RSpec.describe DtextPreviewsController do
  let(:member) { create(:user) }

  before do
    allow(RateLimiter).to receive(:throttle!).and_return(false)
  end

  # ---------------------------------------------------------------------------
  # POST /dtext_preview — create
  # ---------------------------------------------------------------------------

  describe "POST /dtext_preview" do
    context "as anonymous" do
      it "redirects HTML requests to the login page" do
        post dtext_preview_path, params: { body: "hello" }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON requests" do
        post dtext_preview_path(format: :json), params: { body: "hello" }
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body["success"]).to be(false)
        expect(response.parsed_body["reason"]).to include("Must be logged in")
      end

      it "does not render the body" do
        allow(DText).to receive(:parse)
        post dtext_preview_path(format: :json), params: { body: "hello" }
        expect(DText).not_to have_received(:parse)
      end
    end

    context "as a signed-in member" do
      before { sign_in_as member }

      it "returns 200" do
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

      it "treats a non-string body as empty" do
        post dtext_preview_path, params: { body: ["[b]x[/b]"] }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["html"]).not_to include("<strong>")
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

      it "counts the request against a per-user limiter" do
        post dtext_preview_path, params: { body: "hello" }
        expect(RateLimiter).to have_received(:throttle!).with("dtext_preview:#{member.id}", limit: 20, period: 1.minute)
      end

      it "returns 429 when the rate limit is exceeded" do
        allow(RateLimiter).to receive(:throttle!).and_return(true)
        allow(DText).to receive(:parse)
        post dtext_preview_path(format: :json), params: { body: "hello" }
        expect(response).to have_http_status(:too_many_requests)
        expect(DText).not_to have_received(:parse)
      end

      context "with a small input cap" do
        before do
          allow(Danbooru.config.custom_configuration).to receive(:dtext_preview_max_size).and_return(10)
        end

        it "returns 413 without parsing when the body exceeds the cap" do
          allow(DText).to receive(:parse)
          post dtext_preview_path(format: :json), params: { body: "a" * 11 }
          expect(response).to have_http_status(:content_too_large)
          expect(response.parsed_body["success"]).to be(false)
          expect(response.parsed_body["message"]).to include("too long")
          expect(DText).not_to have_received(:parse)
        end

        it "accepts a body exactly at the cap" do
          post dtext_preview_path(format: :json), params: { body: "a" * 10 }
          expect(response).to have_http_status(:ok)
        end

        it "measures the cap in characters, not bytes" do
          post dtext_preview_path(format: :json), params: { body: "é" * 10 }
          expect(response).to have_http_status(:ok)
        end
      end

      it "returns 413 when the rendered output exceeds the output cap" do
        stub_const("DtextPreviewsController::MAX_OUTPUT_BYTES", 16)
        post dtext_preview_path(format: :json), params: { body: "[b]bold[/b]" }
        expect(response).to have_http_status(:content_too_large)
        expect(response.parsed_body["message"]).to include("too large")
      end
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
