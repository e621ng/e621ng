# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplicationRequestsController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  let(:valid_params) do
    { tag_implication_request: { antecedent_name: "test_ant", consequent_name: "test_con", reason: "A good enough reason" } }
  end

  # ---------------------------------------------------------------------------
  # GET /tag_implication_request/new
  # ---------------------------------------------------------------------------

  describe "GET /tag_implication_request/new" do
    it "redirects anonymous to the login page" do
      get new_tag_implication_request_path
      expect(response).to redirect_to(new_session_path(url: new_tag_implication_request_path))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_tag_implication_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tag_implication_request
  # ---------------------------------------------------------------------------

  describe "POST /tag_implication_request" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post tag_implication_request_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post tag_implication_request_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a TagImplication with valid params" do
        expect { post tag_implication_request_path, params: valid_params }.to change(TagImplication, :count).by(1)
      end

      it "creates a forum topic alongside the implication" do
        expect { post tag_implication_request_path, params: valid_params }.to change(ForumTopic, :count).by(1)
      end

      it "redirects to the forum topic after creation" do
        post tag_implication_request_path, params: valid_params
        expect(response).to redirect_to(forum_topic_path(ForumTopic.last))
      end

      it "does not create a TagImplication when reason is too short" do
        params = { tag_implication_request: { antecedent_name: "test_ant", consequent_name: "test_con", reason: "no" } }
        expect { post tag_implication_request_path, params: params }.not_to change(TagImplication, :count)
      end

      it "re-renders new when params are invalid" do
        params = { tag_implication_request: { antecedent_name: "test_ant", consequent_name: "test_con", reason: "no" } }
        post tag_implication_request_path, params: params
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 when a member passes the skip_forum param (unpermitted)" do
        params = { tag_implication_request: { antecedent_name: "test_ant", consequent_name: "test_con", reason: "A good enough reason", skip_forum: "1" } }
        post tag_implication_request_path, params: params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "accepts skip_forum and creates a TagImplication without a forum topic" do
        params = { tag_implication_request: { antecedent_name: "admin_ant", consequent_name: "admin_con", skip_forum: "1" } }
        expect { post tag_implication_request_path, params: params }.to change(TagImplication, :count).by(1)
        expect(TagImplication.last.forum_topic).to be_nil
      end

      it "redirects to the tag implication when skip_forum is used" do
        params = { tag_implication_request: { antecedent_name: "admin_ant2", consequent_name: "admin_con2", skip_forum: "1" } }
        post tag_implication_request_path, params: params
        expect(response).to redirect_to(tag_implication_path(TagImplication.last))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_lockdown_disabled — cross-cutting lockdown behaviour
  # ---------------------------------------------------------------------------

  describe "lockdown behaviour" do
    before do
      allow(Security::Lockdown).to receive(:aiburs_disabled?).and_return(true)
    end

    it "returns 403 for a member on GET new" do
      sign_in_as member
      get new_tag_implication_request_path
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (moderator) through when locked down" do
      sign_in_as moderator
      get new_tag_implication_request_path
      expect(response).to have_http_status(:ok)
    end
  end
end
