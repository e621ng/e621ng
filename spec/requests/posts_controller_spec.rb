# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostsController do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # GET /posts — index
  # ---------------------------------------------------------------------------

  describe "GET /posts" do
    # Stub tag_match to avoid stale ES index documents from rolled-back
    # transactions returning IDs that no longer exist in the DB.
    before { allow(Post).to receive(:tag_match).and_return(Post.all) }

    it "returns 200 for anonymous" do
      get posts_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a posts collection in the legacy format" do
      create(:post)

      get posts_path(format: :json)
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body.keys).to include("posts")
      expect(body["posts"].first).to include("id", "file", "score", "tags")
    end

    it "returns a post collection in the default v2 format" do
      create(:post)

      get posts_path(format: :json), params: { v2: "true" }
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.first).to include("id", "files", "stats", "tags")
      expect(body.first["tags"]).to be_an(Array)
    end

    it "returns a post collection in the extended v2 format when requested" do
      create(:post)

      get posts_path(format: :json), params: { v2: "true", mode: "extended" }
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.first).to include("id", "files", "stats", "tags")
      expect(body.first["tags"]).to be_an(Hash)
      expect(body.first["tags"]).to include("general")
      expect(body.first["tags"]["general"]).to be_an(Array)
    end

    it "returns a post collection in the thumbnail v2 format when requested" do
      create(:post)

      get posts_path(format: :json), params: { v2: "true", mode: "thumbnail" }
      expect(response).to have_http_status(:ok)

      body = response.parsed_body
      expect(body).to be_an(Array)
      expect(body.first).to include("id", "tags", "rating", "file_ext", "uploader_id")
    end

    context "with a md5 param matching a post" do
      let(:post) { create(:post) }

      it "redirects to the post page for HTML" do
        get posts_path(md5: post.md5)
        expect(response).to redirect_to(post_path(post))
      end

      it "returns the wrapped post as JSON" do
        get posts_path(md5: post.md5, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post" => hash_including("id" => post.id))
      end
    end

    context "with an md5 param that matches no post" do
      it "returns 404" do
        get posts_path(md5: "00000000000000000000000000000000")
        expect(response).to have_http_status(:not_found)
      end

      it "doesn't crash when md5 param is a hash" do
        get posts_path, params: { md5: { "$eq" => "" } }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id" do
    let(:post) { create(:post) }

    it "returns 200 for an existing post" do
      get post_path(post)
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON body containing the post id" do
      get post_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("post" => hash_including("id" => post.id))
    end

    it "returns 404 for a non-existent post" do
      get post_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end

    context "when the post is not visible due to lockdown" do
      before { allow(Security::Lockdown).to receive(:post_visible?).and_return(false) }

      it "redirects an anonymous visitor to the login page" do
        get post_path(post)
        expect(response).to redirect_to(new_session_path(url: post_path(post)))
      end

      it "returns 403 for a logged-in member" do
        sign_in_as create(:user)
        get post_path(post)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "doesn't crash when pool_id is an array" do
      get post_path(post), params: { pool_id: ["49413"] }
      assert_response :success
    end

    it "doesn't crash when post_set_id is an array" do
      get post_path(post), params: { post_set_id: ["12345"] }
      assert_response :success
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id/show_seq — show_seq
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/show_seq" do
    let(:post) { create(:post) }

    it "returns 200 for an existing post" do
      get show_seq_post_path(post)
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON body containing the post id" do
      get show_seq_post_path(post, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("post" => hash_including("id" => post.id))
    end

    context "when the post is not visible due to lockdown" do
      before { allow(Security::Lockdown).to receive(:post_visible?).and_return(false) }

      it "redirects an anonymous visitor to the login page" do
        get show_seq_post_path(post)
        expect(response).to redirect_to(new_session_path(url: show_seq_post_path(post)))
      end

      it "returns 403 for a logged-in member" do
        sign_in_as create(:user)
        get show_seq_post_path(post)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/random — random
  # ---------------------------------------------------------------------------

  describe "GET /posts/random" do
    context "when at least one post exists" do
      let!(:post) { create(:post) }

      # Stub tag_match to avoid the transactional-fixtures / ES-index staleness
      # issue. (ES retains documents from rolled-back transactions; stale IDs
      # score higher than the fresh post and return nil when queried against the DB.)
      before { allow(Post).to receive(:tag_match).and_return(Post.where(id: post.id)) }

      it "redirects to a post page for HTML" do
        get random_posts_path
        expect(response).to have_http_status(:found)
        expect(response.location).to match(%r{/posts/\d+})
      end

      it "returns a wrapped post as JSON" do
        get random_posts_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post" => hash_including("id"))
      end
    end

    context "when no posts match the tags param" do
      it "returns 404" do
        get random_posts_path(tags: "thisdoesnotexist_____")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /posts/:id — update (member_only, ensure_lockdown_disabled)
  # ---------------------------------------------------------------------------

  describe "PUT /posts/:id" do
    let(:post) { create(:post) }
    let(:valid_params) { { post: { source: "https://example.com" } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        put post_path(post), params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        put post_path(post, format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      let(:member) { create(:user) }

      before { sign_in_as member }

      it "redirects to the post page after a successful update" do
        put post_path(post), params: valid_params
        expect(response).to redirect_to(post_path(post))
      end

      it "returns the updated post as JSON" do
        put post_path(post, format: :json), params: valid_params
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post" => hash_including("id" => post.id))
      end

      context "when the post edit throttle is exceeded" do
        before { allow(member).to receive(:can_post_edit_with_reason).and_return(:REJ_LIMITED) }

        it "returns 403 for HTML" do
          put post_path(post), params: valid_params
          expect(response).to have_http_status(:forbidden)
        end

        it "returns 403 for JSON" do
          put post_path(post, format: :json), params: valid_params
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when uploads are disabled" do
        before { allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true) }

        it "returns 403" do
          put post_path(post), params: valid_params
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "as staff when uploads are disabled" do
      before do
        sign_in_as create(:janitor_user)
        allow(Security::Lockdown).to receive(:uploads_disabled?).and_return(true)
      end

      it "succeeds — lockdown does not apply to staff" do
        put post_path(post), params: valid_params
        expect(response).to redirect_to(post_path(post))
      end
    end

    describe "permitted params by role" do
      context "as a regular member" do
        before { sign_in_as create(:user) }

        it "ignores is_rating_locked" do
          put post_path(post), params: { post: { is_rating_locked: true } }
          expect(post.reload.is_rating_locked).to be false
        end
      end

      context "as a privileged user" do
        before { sign_in_as create(:privileged_user) }

        it "allows setting is_rating_locked" do
          put post_path(post), params: { post: { is_rating_locked: true } }
          expect(post.reload.is_rating_locked).to be true
        end
      end

      context "as a janitor" do
        before { sign_in_as create(:janitor_user) }

        it "allows setting is_note_locked" do
          put post_path(post), params: { post: { is_note_locked: true } }
          expect(post.reload.is_note_locked).to be true
        end
      end

      context "as an admin" do
        before { sign_in_as create(:admin_user) }

        it "allows setting is_status_locked" do
          put post_path(post), params: { post: { is_status_locked: true } }
          expect(post.reload.is_status_locked).to be true
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /posts/:id/revert — revert (member_only, ensure_lockdown_disabled)
  # ---------------------------------------------------------------------------

  describe "PUT /posts/:id/revert" do
    let(:post) { create(:post) }

    context "as anonymous" do
      it "redirects to the login page" do
        put revert_post_path(post), params: { version_id: 1 }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "reverts the post to the given version and redirects" do
        version = post.versions.first
        put revert_post_path(post), params: { version_id: version.id }
        expect(response).to have_http_status(:found)
      end

      it "returns 404 for a non-existent version id" do
        put revert_post_path(post), params: { version_id: 0 }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /posts/:id/copy_notes — copy_notes (member_only, ensure_lockdown_disabled)
  # ---------------------------------------------------------------------------

  describe "PUT /posts/:id/copy_notes" do
    let(:source_post) { create(:post) }
    let(:target_post) { create(:post) }

    context "as anonymous" do
      it "redirects to the login page" do
        put copy_notes_post_path(source_post), params: { other_post_id: target_post.id }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      context "when the source post has no notes" do
        it "returns 400 with an error body" do
          put copy_notes_post_path(source_post), params: { other_post_id: target_post.id }
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to include("success" => false)
        end
      end

      context "when copy_notes_to succeeds" do
        before do
          allow(Post).to receive(:find).and_call_original
          allow(Post).to receive(:find).with(source_post.id.to_s).and_return(source_post)
          allow(source_post).to receive(:copy_notes_to).and_return(true)
        end

        it "returns 204 no content" do
          put copy_notes_post_path(source_post), params: { other_post_id: target_post.id }
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /posts/:id/mark_as_translated — mark_as_translated (member_only, …)
  # ---------------------------------------------------------------------------

  describe "PUT /posts/:id/mark_as_translated" do
    let(:post) { create(:post) }

    context "as anonymous" do
      it "redirects to the login page" do
        put mark_as_translated_post_path(post), params: { post: { translated: "1" } }
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "as a member" do
      before { sign_in_as create(:user) }

      it "redirects to the post page after marking as translated" do
        put mark_as_translated_post_path(post), params: { post: { translated: "1" } }
        expect(response).to redirect_to(post_path(post))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /posts/:id/update_iqdb — update_iqdb (admin_only, ensure_lockdown_disabled)
  # ---------------------------------------------------------------------------

  describe "GET /posts/:id/update_iqdb" do
    let(:post) { create(:post) }

    context "as anonymous" do
      it "redirects to the login page, preserving the return URL" do
        get update_iqdb_post_path(post)
        expect(response).to redirect_to(new_session_path(url: update_iqdb_post_path(post)))
      end
    end

    context "as a regular member" do
      before { sign_in_as create(:user) }

      it "returns 403" do
        get update_iqdb_post_path(post)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before do
        sign_in_as create(:admin_user)
        allow(Post).to receive(:find).and_call_original
        allow(Post).to receive(:find).with(post.id.to_s).and_return(post)
        allow(post).to receive(:update_iqdb_async)
      end

      it "succeeds and redirects to the post page" do
        get update_iqdb_post_path(post)
        expect(response).to redirect_to(post_path(post))
      end
    end
  end
end
