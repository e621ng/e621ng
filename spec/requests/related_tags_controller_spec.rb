# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelatedTagsController do
  # Set a current user so factory callbacks that require CurrentUser do not
  # raise inside `let` blocks. Requests override this via sign_in_as.
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:user) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /related_tag — show
  # ---------------------------------------------------------------------------

  describe "GET /related_tag" do
    context "as anonymous" do
      # NOTE: passing a blank query triggers normalize_search's redirect to strip
      # empty params *before* member_only runs. Use a non-blank query so the
      # access-control check is actually reached.
      let(:tag) { create(:tag, name: "anon_test_tag") }

      it "redirects HTML requests to the login page" do
        get related_tag_path, params: { search: { query: tag.name } }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(new_session_path)
      end

      it "returns 403 for JSON requests" do
        get related_tag_path(format: :json), params: { search: { query: tag.name } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "returns 200 for HTML with a non-blank query" do
        tag = create(:tag, name: "html_test_tag")
        get related_tag_path, params: { search: { query: tag.name } }
        expect(response).to have_http_status(:ok)
      end

      it "returns an empty array for JSON when no matching tags exist" do
        tag = create(:tag, name: "no_related_tags")
        get related_tag_path(format: :json), params: { search: { query: tag.name } }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end

      it "returns related tags for a tag with cached related_tags data" do
        tag = create(:tag, name: "foo_source")
        bar = create(:tag, name: "bar_related")
        tag.update_columns(related_tags: "#{bar.name} 5")

        get related_tag_path(format: :json), params: { search: { query: tag.name } }

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        expect(body).to include(include("name" => bar.name, "category_id" => bar.category))
      end

      it "returns matching tags for a wildcard query" do
        create(:tag, name: "wildcard_alpha", post_count: 1)
        create(:tag, name: "wildcard_beta", post_count: 1)
        create(:tag, name: "other_tag", post_count: 1)

        get related_tag_path(format: :json), params: { search: { query: "wildcard*" } }

        expect(response).to have_http_status(:ok)
        names = response.parsed_body.pluck("name")
        expect(names).to include("wildcard_alpha", "wildcard_beta")
        expect(names).not_to include("other_tag")
      end

      it "returns category-filtered related tags when category_id is given" do
        tag = create(:tag, name: "source_tag")
        allow(RelatedTagCalculator).to receive(:calculate_from_sample_to_array).and_return([["related_tag", 3]])
        create(:tag, name: "related_tag", category: 0)

        get related_tag_path(format: :json), params: { search: { query: tag.name, category_id: 0 } }

        expect(response).to have_http_status(:ok)
        expect(RelatedTagCalculator).to have_received(:calculate_from_sample_to_array).with(tag.name, "0")
      end

      it "returns 422 when the query exceeds the tag limit" do
        allow(Danbooru.config.custom_configuration).to receive(:tag_query_limit).and_return(1)

        get related_tag_path, params: { search: { query: "tag_one tag_two" } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /related_tag/bulk — bulk
  # ---------------------------------------------------------------------------

  describe "GET /related_tag/bulk" do
    context "as anonymous" do
      it "returns 403 for JSON" do
        get related_tag_bulk_path(format: :json), params: { query: "" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "returns an empty hash when no query is given" do
        get related_tag_bulk_path(format: :json), params: { query: "" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end

      it "returns a hash of related tags keyed by tag name" do
        tag = create(:tag, name: "bulk_source")
        related = create(:tag, name: "bulk_related")
        tag.update_columns(related_tags: "#{related.name} 7")

        get related_tag_bulk_path(format: :json), params: { query: tag.name }

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_a(Hash)
        expect(body).to have_key(tag.name)
        expect(body[tag.name]).to be_an(Array)
        expect(body[tag.name]).to include(include("name" => related.name, "count" => 7))
      end

      it "returns category-filtered results when category_id is given" do
        tag = create(:tag, name: "bulk_cat_source")
        allow(RelatedTagCalculator).to receive(:calculate_from_sample_to_array).and_return([["cat_related", 4]])
        create(:tag, name: "cat_related", category: 1)

        get related_tag_bulk_path(format: :json), params: { query: tag.name, category_id: 1 }

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key(tag.name)
        expect(RelatedTagCalculator).to have_received(:calculate_from_sample_to_array).with(tag.name, "1")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /related_tag/bulk — bulk via POST
  # ---------------------------------------------------------------------------

  describe "POST /related_tag/bulk" do
    context "as anonymous" do
      it "returns 403 for JSON" do
        post related_tag_bulk_path(format: :json), params: { query: "" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as user }

      it "returns an empty hash when no query is given" do
        post related_tag_bulk_path(format: :json), params: { query: "" }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({})
      end
    end
  end
end
