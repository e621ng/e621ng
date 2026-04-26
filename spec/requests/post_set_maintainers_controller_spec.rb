# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSetMaintainersController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:owner)      { create(:user) }
  let(:invitee)    { create(:user) }
  let(:other_user) { create(:user) }
  let(:post_set)   { create(:public_post_set, creator: owner) }

  let(:pending_maintainer)  { create(:post_set_maintainer, post_set: post_set, user: invitee) }
  let(:approved_maintainer) { create(:approved_post_set_maintainer, post_set: post_set, user: invitee) }
  let(:blocked_maintainer)  { create(:blocked_post_set_maintainer, post_set: post_set, user: invitee) }

  # ---------------------------------------------------------------------------
  # GET /post_set_maintainers — index
  # ---------------------------------------------------------------------------

  describe "GET /post_set_maintainers" do
    it "redirects anonymous to the login page" do
      get post_set_maintainers_path
      expect(response).to redirect_to(new_session_path(url: post_set_maintainers_path))
    end

    context "as a member" do
      before { sign_in_as invitee }

      it "returns 200" do
        get post_set_maintainers_path
        expect(response).to have_http_status(:ok)
      end

      it "shows only the current user's invites" do
        my_invite    = pending_maintainer
        other_set    = create(:public_post_set, creator: owner)
        other_invite = create(:post_set_maintainer, post_set: other_set, user: other_user)

        get post_set_maintainers_path

        expect(response.body).to include(my_invite.post_set.name)
        expect(response.body).not_to include(other_invite.post_set.name)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /post_set_maintainers — create
  # ---------------------------------------------------------------------------

  describe "POST /post_set_maintainers" do
    let(:valid_params) { { post_set_id: post_set.id, username: invitee.name } }

    it "redirects anonymous to the login page" do
      post post_set_maintainers_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other_user
      post post_set_maintainers_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as the set owner" do
      before { sign_in_as owner }

      it "creates an invite and redirects with a success flash" do
        expect { post post_set_maintainers_path, params: valid_params }
          .to change(PostSetMaintainer, :count).by(1)
        expect(response).to redirect_to(maintainers_post_set_path(post_set))
        expect(flash[:notice]).to include("invited to be a maintainer")
      end

      it "redirects with an error flash when the username is not found" do
        post post_set_maintainers_path, params: { post_set_id: post_set.id, username: "nonexistent_user_xyz" }
        expect(response).to redirect_to(maintainers_post_set_path(post_set))
        expect(flash[:notice]).to include("not found")
      end

      it "redirects with a validation error when inviting the set owner" do
        post post_set_maintainers_path, params: { post_set_id: post_set.id, username: owner.name }
        expect(response).to redirect_to(maintainers_post_set_path(post_set))
        expect(flash[:notice]).to include("owns this set")
      end

      it "redirects with a validation error when the set is private" do
        private_set = create(:post_set, creator: owner)
        post post_set_maintainers_path, params: { post_set_id: private_set.id, username: invitee.name }
        expect(response).to redirect_to(maintainers_post_set_path(private_set))
        expect(flash[:notice]).to include("must be public")
      end

      it "redirects with an error when the user already has a pending invite" do
        pending_maintainer
        post post_set_maintainers_path, params: valid_params
        expect(response).to redirect_to(maintainers_post_set_path(post_set))
        expect(flash[:notice]).to include("Already a maintainer")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /post_set_maintainers/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /post_set_maintainers/:id" do
    it "redirects anonymous to the login page" do
      delete post_set_maintainer_path(pending_maintainer)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other_user
      delete post_set_maintainer_path(pending_maintainer)
      expect(response).to have_http_status(:forbidden)
    end

    context "as the set owner" do
      before { sign_in_as owner }

      it "returns 403 when the maintainer status is blocked" do
        delete post_set_maintainer_path(blocked_maintainer)
        expect(response).to have_http_status(:forbidden)
      end

      it "transitions a pending invite to cooldown without deleting the record" do
        maintainer = pending_maintainer
        expect { delete post_set_maintainer_path(maintainer) }
          .not_to change(PostSetMaintainer, :count)
        expect(maintainer.reload.status).to eq("cooldown")
      end

      it "destroys an approved maintainer record" do
        maintainer = approved_maintainer
        expect { delete post_set_maintainer_path(maintainer) }
          .to change(PostSetMaintainer, :count).by(-1)
        expect(PostSetMaintainer.find_by(id: maintainer.id)).to be_nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_set_maintainers/:id/approve — approve
  # ---------------------------------------------------------------------------

  describe "GET /post_set_maintainers/:id/approve" do
    it "redirects anonymous to the login page" do
      get approve_post_set_maintainer_path(pending_maintainer)
      expect(response).to redirect_to(new_session_path(url: approve_post_set_maintainer_path(pending_maintainer)))
    end

    it "returns 403 for the wrong user" do
      sign_in_as other_user
      get approve_post_set_maintainer_path(pending_maintainer)
      expect(response).to have_http_status(:forbidden)
    end

    context "as the invited user" do
      before { sign_in_as invitee }

      it "approves a pending invite and redirects with a notice" do
        maintainer = pending_maintainer
        get approve_post_set_maintainer_path(maintainer)
        expect(maintainer.reload.status).to eq("approved")
        expect(response).to redirect_to(post_set_maintainers_path)
        expect(flash[:notice]).to include("You are now a maintainer")
      end

      it "returns 403 when the invite is already approved" do
        get approve_post_set_maintainer_path(approved_maintainer)
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 403 when the user is blocked" do
        get approve_post_set_maintainer_path(blocked_maintainer)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_set_maintainers/:id/deny — deny
  # ---------------------------------------------------------------------------

  describe "GET /post_set_maintainers/:id/deny" do
    it "redirects anonymous to the login page" do
      get deny_post_set_maintainer_path(pending_maintainer)
      expect(response).to redirect_to(new_session_path(url: deny_post_set_maintainer_path(pending_maintainer)))
    end

    it "returns 403 for the wrong user" do
      sign_in_as other_user
      get deny_post_set_maintainer_path(pending_maintainer)
      expect(response).to have_http_status(:forbidden)
    end

    context "as the invited user" do
      before { sign_in_as invitee }

      it "destroys the maintainer record and redirects with a notice" do
        maintainer = pending_maintainer
        expect { get deny_post_set_maintainer_path(maintainer) }
          .to change(PostSetMaintainer, :count).by(-1)
        expect(response).to redirect_to(post_set_maintainers_path)
        expect(flash[:notice]).to include("declined")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /post_set_maintainers/:id/block — block
  # ---------------------------------------------------------------------------

  describe "GET /post_set_maintainers/:id/block" do
    it "redirects anonymous to the login page" do
      get block_post_set_maintainer_path(pending_maintainer)
      expect(response).to redirect_to(new_session_path(url: block_post_set_maintainer_path(pending_maintainer)))
    end

    it "returns 403 for the wrong user" do
      sign_in_as other_user
      get block_post_set_maintainer_path(pending_maintainer)
      expect(response).to have_http_status(:forbidden)
    end

    context "as the invited user" do
      before { sign_in_as invitee }

      it "returns 403 when the user is already blocked" do
        get block_post_set_maintainer_path(blocked_maintainer)
        expect(response).to have_http_status(:forbidden)
      end

      it "sets the status to blocked and redirects with a notice" do
        maintainer = pending_maintainer
        get block_post_set_maintainer_path(maintainer)
        expect(maintainer.reload.status).to eq("blocked")
        expect(response).to redirect_to(post_set_maintainers_path)
        expect(flash[:notice]).to include("further invites")
      end
    end
  end
end
