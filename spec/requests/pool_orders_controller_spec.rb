# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolOrdersController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:pool)   { create(:pool) }

  # ---------------------------------------------------------------------------
  # GET /pools/:pool_id/order/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /pools/:pool_id/order/edit" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        get edit_pool_order_path(pool)
        expect(response).to redirect_to(new_session_path(url: edit_pool_order_path(pool)))
      end

      it "returns 403 for JSON" do
        get edit_pool_order_path(pool, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "returns 200 for HTML" do
        get edit_pool_order_path(pool)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for JSON" do
        get edit_pool_order_path(pool, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for a nonexistent pool" do
        get edit_pool_order_path(pool_id: 0)
        expect(response).to have_http_status(:not_found)
      end

      context "with posts in the pool" do
        let(:posts) { create_list(:post, 2) }
        let(:pool)  { create(:pool, post_ids: posts.map(&:id)) }
        let(:doc)   { response.parsed_body }

        before do
          # Stats follow the user's setting, exactly like /posts
          member.update!(show_post_statistics: true)
          get edit_pool_order_path(pool)
        end

        it "renders the posts in the shared post grid" do
          expect(doc.css("section.posts-container .sortable-thumbnail").pluck("data-id")).to eq(posts.map { |p| p.id.to_s })
        end

        it "renders one move handle per post" do
          expect(doc.css(".sortable-thumbnail > .sortable-handle svg[name='move']").size).to eq(2)
        end

        it "shows the normal post statistics bar" do
          expect(doc.css(".sortable-thumbnail article.thumbnail .thm-desc").size).to eq(2)
        end

        it "keeps the order form field" do
          expect(doc.at_css("#ordering-form input#pool_post_ids_string")["value"]).to eq(pool.post_ids_string)
        end
      end

      context "with a post hidden from the viewer" do
        let(:visible_post) { create(:post, rating: "s") }
        let(:hidden_post)  { create(:post, rating: "e") }
        let(:pool)         { create(:pool, post_ids: [visible_post.id, hidden_post.id]) }
        let(:doc)          { response.parsed_body }
        let(:hidden_item)  { doc.at_css(".sortable-thumbnail[data-id='#{hidden_post.id}']") }

        before do
          # Safe mode blocks non-safe posts, so the explicit post renders the fallback.
          # (sign_in_as bypasses SessionLoader, so the user setting wouldn't apply; use the site's.)
          allow(Danbooru.config.custom_configuration).to receive(:safe_mode?).and_return(true)
          get edit_pool_order_path(pool)
        end

        it "keeps the hidden post as a reorderable slot with a fallback in place of the thumbnail" do
          expect(hidden_item.at_css(".sortable-hidden-post").text).to eq("Hidden: Post ##{hidden_post.id}")
          expect(hidden_item.at_css(".sortable-handle")).to be_present
        end

        it "does not expose the hidden post's thumbnail" do
          expect(hidden_item.css("article, img, picture")).to be_empty
          expect(response.body).not_to include(hidden_post.md5)
        end

        it "still renders the visible post normally" do
          expect(doc.at_css(".sortable-thumbnail[data-id='#{visible_post.id}'] article.thumbnail")).to be_present
        end
      end
    end
  end
end
