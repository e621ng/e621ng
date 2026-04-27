# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserNameChangeRequestsController do
  # Set a current user before each example so that factory callbacks that
  # require a current user do not raise NoMethodError inside `let` blocks.
  # Requests override this via the `sign_in_as` stub.
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)       { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator)    { create(:moderator_user) }
  let(:change_request) { create(:user_name_change_request, user: other_member) }

  # ---------------------------------------------------------------------------
  # GET /user_name_change_requests — index (moderator only)
  # ---------------------------------------------------------------------------

  describe "GET /user_name_change_requests" do
    it "redirects anonymous to the login page" do
      get user_name_change_requests_path
      expect(response).to redirect_to(new_session_path(url: user_name_change_requests_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get user_name_change_requests_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for a moderator" do
      sign_in_as moderator
      get user_name_change_requests_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for a moderator" do
      sign_in_as moderator
      get user_name_change_requests_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with multiple records" do
      let!(:target_request) { create(:user_name_change_request, user: create(:user)) }
      let!(:other_request)  { create(:user_name_change_request, user: create(:user)) }

      before { sign_in_as moderator }

      it "filters by original_name" do
        get user_name_change_requests_path(format: :json, search: { original_name: target_request.original_name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(target_request.id)
        expect(ids).not_to include(other_request.id)
      end

      it "filters by desired_name" do
        get user_name_change_requests_path(format: :json, search: { desired_name: target_request.desired_name })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(target_request.id)
        expect(ids).not_to include(other_request.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /user_name_change_requests/:id — show (member + ownership check)
  # ---------------------------------------------------------------------------

  describe "GET /user_name_change_requests/:id" do
    it "redirects anonymous to the login page" do
      get user_name_change_request_path(change_request)
      expect(response).to redirect_to(new_session_path(url: user_name_change_request_path(change_request)))
    end

    it "returns 403 for a member who does not own the request" do
      sign_in_as member
      get user_name_change_request_path(change_request)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for the owning member" do
      sign_in_as other_member
      get user_name_change_request_path(change_request)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a moderator viewing another user's request" do
      sign_in_as moderator
      get user_name_change_request_path(change_request)
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON with the record id for the owner" do
      sign_in_as other_member
      get user_name_change_request_path(change_request, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => change_request.id)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /user_name_change_requests/new — new (member only)
  # ---------------------------------------------------------------------------

  describe "GET /user_name_change_requests/new" do
    it "redirects anonymous to the login page" do
      get new_user_name_change_request_path
      expect(response).to redirect_to(new_session_path(url: new_user_name_change_request_path))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_user_name_change_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /user_name_change_requests — create (member only)
  # ---------------------------------------------------------------------------

  describe "POST /user_name_change_requests" do
    let(:valid_params) { { user_name_change_request: { desired_name: "NewValidName" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post user_name_change_requests_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post user_name_change_requests_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a request and redirects with a success flash" do
        expect { post user_name_change_requests_path, params: valid_params }.to change(UserNameChangeRequest, :count).by(1)
        expect(response).to redirect_to(user_name_change_request_path(UserNameChangeRequest.last))
        expect(flash[:notice]).to eq("Your name has been changed")
      end

      it "updates the user's name via the apply! callback" do
        post user_name_change_requests_path, params: valid_params
        expect(member.reload.name).to eq("NewValidName")
      end

      it "re-renders new when desired_name is blank" do
        post user_name_change_requests_path, params: { user_name_change_request: { desired_name: "" } }
        expect(response).to have_http_status(:ok)
      end

      it "re-renders new when desired_name is already taken by another user" do
        taken_user = create(:user)
        post user_name_change_requests_path, params: { user_name_change_request: { desired_name: taken_user.name } }
        expect(response).to have_http_status(:ok)
      end

      it "re-renders new when the weekly rate limit is exceeded" do
        create(:user_name_change_request, user: member)
        post user_name_change_requests_path, params: valid_params
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /user_name_change_requests/:id — destroy (moderator only)
  # ---------------------------------------------------------------------------

  describe "DELETE /user_name_change_requests/:id" do
    it "redirects anonymous to the login page" do
      delete user_name_change_request_path(change_request)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete user_name_change_request_path(change_request)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a moderator" do
      before { sign_in_as moderator }

      it "destroys the record and redirects with a success flash" do
        req_id = change_request.id
        expect { delete user_name_change_request_path(change_request) }.to change(UserNameChangeRequest, :count).by(-1)
        expect(UserNameChangeRequest.find_by(id: req_id)).to be_nil
        expect(response).to redirect_to(user_name_change_requests_path)
        expect(flash[:notice]).to eq("Name change request deleted")
      end
    end
  end
end
