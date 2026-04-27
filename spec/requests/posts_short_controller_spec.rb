# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostsShortController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  describe "GET /p/:id" do
    context "with a valid base-32 ID for an existing post" do
      let(:post) { create(:post) }
      let(:short_id) { post.id.to_s(32) }

      it "redirects to the canonical post page" do
        get p_path(short_id)
        expect(response).to redirect_to(post_path(post))
      end

      it "redirects to the JSON post path when JSON format is requested" do
        get p_path(short_id, format: :json)
        expect(response).to redirect_to(post_path(post, format: :json))
      end
    end

    context "with an invalid base-32 string" do
      it "returns 404" do
        get p_path("!!!")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a valid base-32 integer that has no matching post" do
      it "returns 404" do
        get p_path(0.to_s(32))
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
