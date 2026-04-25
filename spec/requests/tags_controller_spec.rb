# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagsController do
  # Set a current user before each example so that factory callbacks that
  # require a current user do not raise NoMethodError inside `let` blocks.
  # Requests override this via SessionLoader#load — either through the
  # `sign_in_as` stub or the real loader (which always resets to anonymous).
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # ---------------------------------------------------------------------------
  # GET /tags — index
  # ---------------------------------------------------------------------------

  describe "GET /tags" do
    it "returns 200 for anonymous" do
      get tags_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with JSON format" do
      get tags_path(format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "with search params" do
      let!(:matching_tag) { create(:tag, name: "fluffy_tail", post_count: 5) }
      let!(:artist_tag)   { create(:artist_tag, post_count: 5) }

      before do
        create(:tag, name: "sharp_claws", post_count: 5)
        create(:tag, name: "unused_tag",  post_count: 0)
      end

      it "filters by name_matches" do
        get tags_path(format: :json, search: { name_matches: "fluffy_tail", hide_empty: "no" })
        names = response.parsed_body.pluck("name")
        expect(names).to include("fluffy_tail")
        expect(names).not_to include("sharp_claws")
      end

      it "hides empty tags by default" do
        get tags_path(format: :json, search: { name_matches: "unused_tag" })
        names = response.parsed_body.pluck("name")
        expect(names).not_to include("unused_tag")
      end

      it "includes empty tags when hide_empty is no" do
        get tags_path(format: :json, search: { name_matches: "unused_tag", hide_empty: "no" })
        names = response.parsed_body.pluck("name")
        expect(names).to include("unused_tag")
      end

      it "filters by category" do
        get tags_path(format: :json, search: { category: "1", hide_empty: "no" })
        names = response.parsed_body.pluck("name")
        expect(names).to include(artist_tag.name)
        expect(names).not_to include(matching_tag.name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tags/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /tags/:id" do
    let(:tag) { create(:tag) }

    it "returns 200 when looking up by numeric ID" do
      get tag_path(tag.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 when looking up by name" do
      get tag_path(tag.name)
      expect(response).to have_http_status(:ok)
    end

    it "returns tag data as JSON" do
      get tag_path(tag.id, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => tag.id, "name" => tag.name)
    end

    it "returns 404 for a non-existent numeric ID" do
      get tag_path(0)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a non-existent name" do
      get tag_path("this_tag_does_not_exist")
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tags/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /tags/:id/edit" do
    let(:tag)            { create(:tag) }
    let(:locked_tag)     { create(:locked_tag) }
    let(:big_tag)        { create(:high_post_count_tag) }
    let(:meta_tag)       { create(:meta_tag) }
    let(:invalid_tag)    { create(:invalid_tag) }
    let(:lore_tag_name)  { "lore_subject_(lore)" }

    context "as anonymous" do
      it "redirects to login for HTML" do
        get edit_tag_path(tag)
        expect(response).to redirect_to(new_session_path(url: edit_tag_path(tag)))
      end

      it "returns 403 for JSON" do
        get edit_tag_path(tag, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 200 for an editable tag" do
        get edit_tag_path(tag)
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 for a locked tag" do
        get edit_tag_path(locked_tag)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for a high-post-count tag" do
        get edit_tag_path(big_tag)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for a meta-category tag" do
        get edit_tag_path(meta_tag)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 for an invalid-category tag" do
        get edit_tag_path(invalid_tag)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in_as create(:admin_user) }

      it "returns 200 for a locked tag" do
        get edit_tag_path(locked_tag)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a high-post-count tag" do
        get edit_tag_path(big_tag)
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a meta-category tag" do
        get edit_tag_path(meta_tag)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the referer is a wiki page" do
      before { sign_in_as create(:user) }

      it "returns 200 (from_wiki flag is view-layer only)" do
        get edit_tag_path(tag), headers: { "HTTP_REFERER" => "http://example.com/wiki_pages/some_page" }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /tags/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /tags/:id" do
    let(:tag)        { create(:tag, category: 0) }
    let(:locked_tag) { create(:locked_tag, category: 0) }

    context "as anonymous" do
      it "redirects to login for HTML" do
        patch tag_path(tag), params: { tag: { category: 1 } }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch tag_path(tag, format: :json), params: { tag: { category: 1 } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      let(:member) { create(:user) }

      before { sign_in_as member }

      it "updates the category and redirects to the tag search" do
        patch tag_path(tag), params: { tag: { category: 1 } }
        expect(tag.reload.category).to eq(1)
        expect(response).to redirect_to(tags_path(search: { name_matches: tag.name, hide_empty: "no" }))
      end

      it "redirects to the wiki page when from_wiki is set" do
        patch tag_path(tag), params: { tag: { category: 1, from_wiki: "1" } }
        expect(response).to redirect_to(show_or_new_wiki_pages_path(title: WikiPage.normalize_name(tag.name)))
      end

      it "returns 403 when updating a locked tag" do
        patch tag_path(locked_tag), params: { tag: { category: 1 } }
        expect(response).to have_http_status(:forbidden)
      end

      it "does not allow a member to change is_locked" do
        patch tag_path(tag), params: { tag: { is_locked: true } }
        expect(tag.reload.is_locked).to be false
      end

      it "returns 204 No Content for JSON (respond_with default for PATCH)" do
        patch tag_path(tag, format: :json), params: { tag: { category: 1 } }
        expect(response).to have_http_status(:no_content)
      end
    end

    context "as an admin" do
      before { sign_in_as create(:admin_user) }

      it "allows setting is_locked to true" do
        patch tag_path(tag), params: { tag: { is_locked: true } }
        expect(tag.reload.is_locked).to be true
      end

      it "can update a locked tag" do
        patch tag_path(locked_tag), params: { tag: { category: 1 } }
        expect(locked_tag.reload.category).to eq(1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /tags/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /tags/:id" do
    let(:tag) { create(:tag) }

    # Post.tag_match hits OpenSearch. Stub it in all destroy examples so tests
    # are self-contained without requiring an indexed search engine.
    # rubocop:disable RSpec/VerifiedDoubles
    let(:post_query_zero) { double(count_only: 0) }
    let(:post_query_one)  { double(count_only: 1) }
    # rubocop:enable RSpec/VerifiedDoubles

    before do
      allow(Post).to receive(:tag_match).and_return(post_query_zero)
    end

    context "as anonymous" do
      before do
        CurrentUser.user = nil
        CurrentUser.ip_addr = nil
      end

      it "redirects to login (non-GET access_denied for anonymous)" do
        delete tag_path(tag)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        delete tag_path(tag)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a moderator" do
      before { sign_in_as create(:moderator_user) }

      it "returns 403" do
        delete tag_path(tag)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin (bd_staff)" do
      before { sign_in_as create(:bd_staff_user) }

      it "destroys a clean tag and redirects to tags_path with notice" do
        delete tag_path(tag)
        expect(response).to redirect_to(tags_path)
        expect(flash[:notice]).to include("Tag destroyed")
        expect(Tag.find_by(id: tag.id)).to be_nil
      end

      context "when the tag has posts" do
        before { allow(Post).to receive(:tag_match).and_return(post_query_one) }

        it "does not destroy the tag and includes the error in the notice" do
          delete tag_path(tag)
          expect(Tag.find_by(id: tag.id)).not_to be_nil
          expect(flash[:notice]).to include("Cannot delete tags that are present on posts")
        end
      end

      context "when the tag has an active alias" do
        before { create(:active_tag_alias, antecedent_name: tag.name) }

        it "does not destroy the tag and includes the error in the notice" do
          delete tag_path(tag)
          expect(Tag.find_by(id: tag.id)).not_to be_nil
          expect(flash[:notice]).to include("Cannot delete tags with active aliases")
        end
      end

      context "when the tag has an active implication" do
        before { create(:active_tag_implication, antecedent_name: tag.name) }

        it "does not destroy the tag and includes the error in the notice" do
          delete tag_path(tag)
          expect(Tag.find_by(id: tag.id)).not_to be_nil
          expect(flash[:notice]).to include("Cannot delete tags with active implications")
        end
      end

      context "when the tag has posts and an active alias" do
        before do
          allow(Post).to receive(:tag_match).and_return(post_query_one)
          create(:active_tag_alias, antecedent_name: tag.name)
        end

        it "includes both error messages joined by semicolons" do
          delete tag_path(tag)
          expect(flash[:notice]).to include("Cannot delete tags that are present on posts")
          expect(flash[:notice]).to include("Cannot delete tags with active aliases")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tags/preview — preview
  # ---------------------------------------------------------------------------

  describe "POST /tags/preview" do
    context "as anonymous" do
      it "redirects to login for HTML" do
        post preview_tags_path
        # POST is not a GET, so access_denied does not include the url param
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "returns 200 with application/json content type" do
        post preview_tags_path, params: { tags: "cat dog" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to start_with("application/json")
      end

      it "returns valid JSON" do
        post preview_tags_path, params: { tags: "cat dog" }
        expect { response.parsed_body }.not_to raise_error
      end

      it "returns 200 with an empty tags param" do
        post preview_tags_path, params: { tags: "" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to start_with("application/json")
      end
    end
  end
end
