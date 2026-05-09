# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSetsController do
  include_context "as admin"

  let(:owner)        { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator)    { create(:moderator_user) }
  let(:admin)        { create(:admin_user) }
  let(:private_set)  { create(:post_set, creator: owner) }
  let(:public_set)   { create(:public_post_set, creator: owner) }

  before do
    allow(RateLimiter).to receive(:check_limit).and_return(false)
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets — index
  # ---------------------------------------------------------------------------

  describe "GET /post_sets" do
    it "returns 200 for anonymous" do
      get post_sets_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a post_sets array in JSON" do
      get post_sets_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with a post_id param" do
      let!(:post) { create(:post) }
      let!(:containing_set)      { create(:public_post_set, creator: owner, post_ids: [post.id]) }
      let!(:private_containing)  { create(:post_set,        creator: owner, post_ids: [post.id]) }

      it "returns all matching sets for a moderator" do
        sign_in_as moderator
        get post_sets_path(post_id: post.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(containing_set.id, private_containing.id)
      end

      it "returns only visible sets for a regular member" do
        sign_in_as other_member
        get post_sets_path(post_id: post.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(containing_set.id)
        expect(ids).not_to include(private_containing.id)
      end
    end

    context "with a maintainer_id param" do
      let!(:maintainer_user) { create(:user) }
      let!(:maintained_set)  { create(:public_post_set, creator: owner) }

      it "returns all maintained sets for a moderator regardless of maintainer_id" do
        sign_in_as moderator
        get post_sets_path(maintainer_id: maintainer_user.id, format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "scopes results to the current user's maintained sets for a non-moderator" do
        sign_in_as other_member
        get post_sets_path(maintainer_id: maintainer_user.id, format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).not_to include(maintained_set.id)
      end
    end

    context "plain search" do
      let!(:own_private_set)    { create(:post_set, creator: other_member) }
      let!(:others_private_set) { private_set }

      it "returns only public and own sets for a regular member" do
        sign_in_as other_member
        get post_sets_path(format: :json)
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(own_private_set.id)
        expect(ids).not_to include(others_private_set.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/:id" do
    it "returns 200 for a public set when anonymous" do
      get post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "redirects anonymous users trying to view a private set" do
      get post_set_path(private_set)
      expect(response).to redirect_to(new_session_path(url: post_set_path(private_set)))
    end

    it "returns 200 for the owner viewing their own private set" do
      sign_in_as owner
      get post_set_path(private_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a moderator viewing any private set" do
      sign_in_as moderator
      get post_set_path(private_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a non-owner member trying to view a private set" do
      sign_in_as other_member
      get post_set_path(private_set)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/new — new
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/new" do
    it "redirects anonymous users to the login page" do
      get new_post_set_path
      expect(response).to redirect_to(new_session_path(url: new_post_set_path))
    end

    it "returns 200 for a logged-in member" do
      sign_in_as other_member
      get new_post_set_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_sets — create
  # ---------------------------------------------------------------------------

  describe "POST /post_sets" do
    let(:valid_params) { { post_set: { name: "My New Set", shortname: "my_new_set", description: "", is_public: false } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post post_sets_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post post_sets_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as other_member }

      it "creates the set and sets a success flash" do
        expect { post post_sets_path, params: valid_params }.to change(PostSet, :count).by(1)
        expect(flash[:notice]).to eq("Set created")
      end

      it "sets an error flash when params are invalid" do
        invalid_params = { post_set: { name: "", shortname: "" } }
        post post_sets_path, params: invalid_params
        expect(flash[:notice]).to be_present
        expect(flash[:notice]).not_to eq("Set created")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/:id/edit — edit
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/:id/edit" do
    it "redirects anonymous users to the login page" do
      get edit_post_set_path(public_set)
      expect(response).to redirect_to(new_session_path(url: edit_post_set_path(public_set)))
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other_member
      get edit_post_set_path(public_set)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for the owner" do
      sign_in_as owner
      get edit_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin editing another user's set" do
      sign_in_as admin
      get edit_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /post_sets/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /post_sets/:id" do
    let(:update_params) { { post_set: { name: "Updated Name", shortname: "updated_name" } } }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        patch post_set_path(public_set), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch post_set_path(public_set, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a non-owner non-admin member" do
      sign_in_as other_member
      patch post_set_path(public_set), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as the owner" do
      before { sign_in_as owner }

      it "updates the set and sets a success flash" do
        patch post_set_path(public_set), params: update_params
        expect(public_set.reload.name).to eq("Updated Name")
        expect(flash[:notice]).to eq("Set updated")
      end
    end

    context "as an admin updating another user's set" do
      before { sign_in_as admin }

      it "logs a set_change_visibility mod action when is_public changes" do
        expect do
          patch post_set_path(public_set), params: { post_set: { is_public: false } }
        end.to change(ModAction, :count).by(1)
        expect(ModAction.last.action).to eq("set_change_visibility")
      end

      it "logs a set_update mod action when watched attributes change" do
        expect do
          patch post_set_path(public_set), params: { post_set: { description: "changed" } }
        end.to change(ModAction, :count).by(1)
        expect(ModAction.last.action).to eq("set_update")
      end

      it "does not double-log when both watched attrs and visibility change together" do
        expect do
          patch post_set_path(public_set), params: { post_set: { is_public: false, description: "changed" } }
        end.to change(ModAction, :count).by(2)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /post_sets/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /post_sets/:id" do
    it "redirects anonymous users to the login page" do
      delete post_set_path(public_set)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-owner non-admin member" do
      sign_in_as other_member
      delete post_set_path(public_set)
      expect(response).to have_http_status(:forbidden)
    end

    it "destroys the set when called by the owner" do
      sign_in_as owner
      set_id = public_set.id
      expect { delete post_set_path(public_set) }.to change(PostSet, :count).by(-1)
      expect(PostSet.find_by(id: set_id)).to be_nil
    end

    it "logs a set_delete mod action when an admin destroys another user's set" do
      sign_in_as admin
      expect do
        delete post_set_path(public_set)
      end.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("set_delete")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/:id/maintainers — maintainers
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/:id/maintainers" do
    it "redirects anonymous users to the login page" do
      get maintainers_post_set_path(public_set)
      expect(response).to redirect_to(new_session_path(url: maintainers_post_set_path(public_set)))
    end

    it "returns 200 for the owner" do
      sign_in_as owner
      get maintainers_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get maintainers_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a member who cannot view the private set" do
      sign_in_as other_member
      get maintainers_post_set_path(private_set)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/:id/post_list — post_list
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/:id/post_list" do
    it "redirects anonymous users to the login page" do
      get post_list_post_set_path(public_set)
      expect(response).to redirect_to(new_session_path(url: post_list_post_set_path(public_set)))
    end

    it "returns 403 for a non-editor member on a private set" do
      sign_in_as other_member
      get post_list_post_set_path(private_set)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for the owner" do
      sign_in_as owner
      get post_list_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an approved maintainer of a public set" do
      maintainer_user = create(:user)
      create(:approved_post_set_maintainer, post_set: public_set, user: maintainer_user)
      sign_in_as maintainer_user
      get post_list_post_set_path(public_set)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for an approved maintainer of a private set" do
      maintainer_user = create(:user)
      # Create the set as public first (factory requires it), then make it private
      # to verify can_edit_posts? returns false when is_public is false.
      set = create(:public_post_set, creator: owner)
      create(:approved_post_set_maintainer, post_set: set, user: maintainer_user)
      set.update_columns(is_public: false)
      sign_in_as maintainer_user
      get post_list_post_set_path(set)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_sets/:id/update_posts — update_posts
  # ---------------------------------------------------------------------------

  describe "POST /post_sets/:id/update_posts" do
    it "redirects anonymous users to the login page" do
      post update_posts_post_set_path(public_set), params: { post_set: { post_ids_string: "" } }
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-editor member" do
      sign_in_as other_member
      post update_posts_post_set_path(private_set), params: { post_set: { post_ids_string: "" } }
      expect(response).to have_http_status(:forbidden)
    end

    context "as the owner" do
      before { sign_in_as owner }

      it "sets a notice and redirects when the set is over the post limit" do
        private_set.update_columns(post_count: Danbooru.config.post_set_post_limit.to_i + 101)
        post update_posts_post_set_path(private_set), params: { post_set: { post_ids_string: "" } }
        expect(flash[:notice]).to match(/too many posts/i)
        expect(response).to redirect_to(post_list_post_set_path(private_set))
      end

      it "redirects to post_list after a successful update with no changes" do
        post update_posts_post_set_path(private_set), params: { post_set: { post_ids_string: "" } }
        expect(flash[:notice]).to eq("Set posts updated")
        expect(response).to redirect_to(post_list_post_set_path(private_set))
      end

      it "performs inline sync and does not enqueue a job when only one post changes" do
        new_post = create(:post)
        expect do
          post update_posts_post_set_path(private_set),
               params: { post_set: { post_ids_string: new_post.id.to_s } }
        end.not_to have_enqueued_job(PostSetPostsSyncJob)
        expect(private_set.reload.post_ids).to include(new_post.id)
      end

      it "enqueues PostSetPostsSyncJob when more than one post changes" do
        posts = create_list(:post, 2)
        expect do
          post update_posts_post_set_path(private_set),
               params: { post_set: { post_ids_string: posts.map(&:id).join(" ") } }
        end.to have_enqueued_job(PostSetPostsSyncJob)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_sets/:id/add_posts — add_posts
  # ---------------------------------------------------------------------------

  describe "POST /post_sets/:id/add_posts" do
    let(:new_post) { create(:post) }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post add_posts_post_set_path(public_set), params: { post_ids: [new_post.id] }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post add_posts_post_set_path(public_set, format: :json), params: { post_ids: [new_post.id] }
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a non-editor member on a private set" do
      sign_in_as other_member
      post add_posts_post_set_path(private_set, format: :json), params: { post_ids: [new_post.id] }
      expect(response).to have_http_status(:forbidden)
    end

    context "as the owner" do
      before { sign_in_as owner }

      it "adds the post to the set and returns a successful response" do
        post add_posts_post_set_path(public_set, format: :json), params: { post_ids: [new_post.id] }
        expect(response).to have_http_status(:success)
        expect(public_set.reload.post_ids).to include(new_post.id)
      end
    end

    context "when adding more than the maximum allowed posts at once" do
      before { sign_in_as owner }

      it "returns a 400 error" do
        allow(Danbooru.config.custom_configuration).to receive(:max_per_page).and_return(3)

        post_ids = create_list(:post, 4).map(&:id)
        post add_posts_post_set_path(public_set, format: :json), params: { post_ids: post_ids }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["message"]).to match(/only add up to/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_sets/:id/remove_posts — remove_posts
  # ---------------------------------------------------------------------------

  describe "POST /post_sets/:id/remove_posts" do
    let(:existing_post) { create(:post) }

    before do
      # Seed the set with a post at the database level to bypass callbacks
      public_set.update_columns(post_ids: [existing_post.id], post_count: 1)
    end

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post remove_posts_post_set_path(public_set), params: { post_ids: [existing_post.id] }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post remove_posts_post_set_path(public_set, format: :json), params: { post_ids: [existing_post.id] }
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a non-editor member on a private set" do
      sign_in_as other_member
      private_set.update_columns(post_ids: [existing_post.id], post_count: 1)
      post remove_posts_post_set_path(private_set, format: :json), params: { post_ids: [existing_post.id] }
      expect(response).to have_http_status(:forbidden)
    end

    context "as the owner" do
      before { sign_in_as owner }

      it "removes the post from the set and returns a successful response" do
        post remove_posts_post_set_path(public_set, format: :json), params: { post_ids: [existing_post.id] }
        expect(response).to have_http_status(:success)
        expect(public_set.reload.post_ids).not_to include(existing_post.id)
      end
    end

    context "when removing more than the maximum allowed posts at once" do
      before { sign_in_as owner }

      it "returns a 400 error" do
        allow(Danbooru.config.custom_configuration).to receive(:max_per_page).and_return(3)

        post_ids = create_list(:post, 4).map(&:id)
        post remove_posts_post_set_path(public_set, format: :json), params: { post_ids: post_ids }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["message"]).to match(/only remove up to/)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_sets/for_select — for_select
  # ---------------------------------------------------------------------------

  describe "GET /post_sets/for_select" do
    it "redirects anonymous users for HTML" do
      get for_select_post_sets_path
      expect(response).to redirect_to(new_session_path(url: for_select_post_sets_path))
    end

    it "returns 403 for anonymous JSON requests" do
      get for_select_post_sets_path(format: :json)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a member" do
      before { sign_in_as owner }

      it "returns JSON with Owned and Maintained groups" do
        get for_select_post_sets_path(format: :json)
        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.keys).to include("Owned", "Maintained")
      end

      it "includes the member's own sets under Owned" do
        public_set # force creation before the request
        get for_select_post_sets_path(format: :json)
        owned_names = response.parsed_body["Owned"].map(&:first)
        expect(owned_names).to include(public_set.name.tr("_", " ").truncate(35))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:post_sets_disabled?).and_return(true)
    end

    it "denies access to a non-staff member when post sets are locked down" do
      sign_in_as other_member
      get new_post_set_path
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (janitor) through when post sets are locked down" do
      sign_in_as create(:janitor_user)
      get new_post_set_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # Throttling
  # ---------------------------------------------------------------------------

  describe "throttling" do
    let(:new_post) { create(:post) }

    before do
      sign_in_as owner
      allow(RateLimiter).to receive(:check_limit).and_return(true)
    end

    it "returns 429 when the rate limit is exceeded while adding posts" do
      post add_posts_post_set_path(public_set), params: { post_ids: [new_post.id] }
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns 429 when the rate limit is exceeded while removing posts" do
      post remove_posts_post_set_path(public_set), params: { post_ids: [new_post.id] }
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns 429 when the rate limit is exceeded while updating posts" do
      post update_posts_post_set_path(public_set), params: { post_set: { post_ids_string: new_post.id.to_s } }
      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
