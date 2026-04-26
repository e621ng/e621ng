# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasRequestsController do
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
    { tag_alias_request: { antecedent_name: "tar_ant_test", consequent_name: "tar_con_test", reason: "These tags should be aliased" } }
  end

  # ---------------------------------------------------------------------------
  # GET /tag_alias_request/new
  # ---------------------------------------------------------------------------

  describe "GET /tag_alias_request/new" do
    it "redirects anonymous to the login page" do
      get new_tag_alias_request_path
      expect(response).to redirect_to(new_session_path(url: new_tag_alias_request_path))
    end

    it "returns 200 for a member" do
      sign_in_as member
      get new_tag_alias_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tag_alias_request
  # ---------------------------------------------------------------------------

  describe "POST /tag_alias_request" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post tag_alias_request_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post tag_alias_request_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member with valid params" do
      before { sign_in_as member }

      it "creates a TagAlias" do
        expect { post tag_alias_request_path, params: valid_params }.to change(TagAlias, :count).by(1)
      end

      it "creates a ForumTopic" do
        expect { post tag_alias_request_path, params: valid_params }.to change(ForumTopic, :count).by(1)
      end

      it "redirects to the forum topic" do
        post tag_alias_request_path, params: valid_params
        expect(response).to redirect_to(forum_topic_path(TagAlias.last.forum_topic))
      end
    end

    context "as a member with the same antecedent and consequent name" do
      before { sign_in_as member }

      let(:invalid_params) do
        { tag_alias_request: { antecedent_name: "same_tag", consequent_name: "same_tag", reason: "These tags should be aliased" } }
      end

      it "does not create a TagAlias" do
        expect { post tag_alias_request_path, params: invalid_params }.not_to change(TagAlias, :count)
      end

      it "re-renders new" do
        post tag_alias_request_path, params: invalid_params
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a member with a reason shorter than 5 characters" do
      before { sign_in_as member }

      let(:short_reason_params) do
        { tag_alias_request: { antecedent_name: "tar_ant_test", consequent_name: "tar_con_test", reason: "no" } }
      end

      it "does not create a TagAlias" do
        expect { post tag_alias_request_path, params: short_reason_params }.not_to change(TagAlias, :count)
      end

      it "re-renders new" do
        post tag_alias_request_path, params: short_reason_params
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a member with skip_forum param (should be stripped)" do
      before { sign_in_as member }

      it "completes without error" do
        params = valid_params.deep_merge(tag_alias_request: { skip_forum: "1" })
        post tag_alias_request_path, params: params
        expect(response).not_to have_http_status(:internal_server_error)
      end
    end

    context "as an admin with skip_forum: \"1\"" do
      before { sign_in_as admin }

      let(:skip_forum_params) do
        { tag_alias_request: { antecedent_name: "tar_ant_admin", consequent_name: "tar_con_admin", reason: "Admin alias, no forum needed", skip_forum: "1" } }
      end

      it "creates a TagAlias" do
        expect { post tag_alias_request_path, params: skip_forum_params }.to change(TagAlias, :count).by(1)
      end

      it "does not create a ForumTopic" do
        expect { post tag_alias_request_path, params: skip_forum_params }.not_to change(ForumTopic, :count)
      end

      it "redirects to the tag alias page" do
        post tag_alias_request_path, params: skip_forum_params
        expect(response).to redirect_to(tag_alias_path(TagAlias.last))
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
      get new_tag_alias_request_path
      expect(response).to have_http_status(:forbidden)
    end

    it "allows staff (moderator) through when locked down" do
      sign_in_as moderator
      get new_tag_alias_request_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a member on POST create" do
      sign_in_as member
      post tag_alias_request_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end
  end
end
