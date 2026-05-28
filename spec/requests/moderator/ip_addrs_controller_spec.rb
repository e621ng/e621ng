# frozen_string_literal: true

require "rails_helper"

RSpec.describe Moderator::IpAddrsController do
  include_context "as admin"

  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }
  let(:member)    { create(:user) }
  let(:target)    { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /moderator/ip_addrs
  # ---------------------------------------------------------------------------

  describe "GET /moderator/ip_addrs" do
    it "redirects anonymous to the login page" do
      get moderator_ip_addrs_path
      expect(response).to redirect_to(new_session_path(url: moderator_ip_addrs_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get moderator_ip_addrs_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      get moderator_ip_addrs_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin with no search params" do
      sign_in_as admin
      get moderator_ip_addrs_path
      expect(response).to have_http_status(:ok)
    end

    context "as an admin" do
      before { sign_in_as admin }

      context "when searching by user_name" do
        it "returns 200 HTML" do
          get moderator_ip_addrs_path, params: { search: { user_name: target.name } }
          expect(response).to have_http_status(:ok)
        end

        it "returns 200 JSON in the correct format" do
          create(:comment, creator: target, creator_ip_addr: "127.0.0.1")
          get moderator_ip_addrs_path(format: :json), params: { search: { user_name: target.name } }
          expect(response).to have_http_status(:ok)

          expect(response.parsed_body).to include("sums", "ip_addrs")
          expect(response.parsed_body["sums"]).to include("comment")
          expect(response.parsed_body["sums"]["comment"]).to include("127.0.0.1" => 1)
          expect(response.parsed_body["ip_addrs"]).to include("127.0.0.1")
        end
      end

      context "when searching by user_id" do
        it "returns 200 HTML" do
          get moderator_ip_addrs_path, params: { search: { user_id: target.id } }
          expect(response).to have_http_status(:ok)
        end

        it "returns 200 JSON in the correct format" do
          create(:comment, creator: target, creator_ip_addr: "127.0.0.1")
          get moderator_ip_addrs_path(format: :json), params: { search: { user_id: target.id } }
          expect(response).to have_http_status(:ok)

          expect(response.parsed_body).to include("sums", "ip_addrs")
          expect(response.parsed_body["sums"]).to include("comment")
          expect(response.parsed_body["sums"]["comment"]).to include("127.0.0.1" => 1)
          expect(response.parsed_body["ip_addrs"]).to include("127.0.0.1")
        end
      end

      context "when searching by ip_addr" do
        it "returns 200 HTML" do
          get moderator_ip_addrs_path, params: { search: { ip_addr: "127.0.0.1" } }
          expect(response).to have_http_status(:ok)
        end

        it "returns 200 JSON in the correct format" do
          create(:comment, creator: target, creator_ip_addr: "127.0.0.1")
          get moderator_ip_addrs_path(format: :json), params: { search: { ip_addr: "127.0.0.1" } }
          expect(response).to have_http_status(:ok)

          expect(response.parsed_body).to include("comment")
          expect(response.parsed_body["comment"]).to include(target.id.to_s)
          expect(response.parsed_body["comment"][target.id.to_s]).to be >= 1
        end

        it "returns 422 for invalid IP address" do
          get moderator_ip_addrs_path, params: { search: { ip_addr: "*dylan*dolly*" } }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns 422 for invalid CIDR prefix" do
          get moderator_ip_addrs_path, params: { search: { ip_addr: "127.0.0.1/999" } }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /moderator/ip_addrs/export
  # ---------------------------------------------------------------------------

  describe "GET /moderator/ip_addrs/export" do
    it "redirects anonymous to the login page" do
      get export_moderator_ip_addrs_path
      expect(response).to redirect_to(new_session_path(url: export_moderator_ip_addrs_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get export_moderator_ip_addrs_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      get export_moderator_ip_addrs_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin with no search params" do
      sign_in_as admin
      get export_moderator_ip_addrs_path(format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "as an admin" do
      before { sign_in_as admin }

      context "when searching by user_name" do
        it "returns 200 JSON" do
          get export_moderator_ip_addrs_path(format: :json), params: { search: { user_name: target.name } }
          expect(response).to have_http_status(:ok)
        end

        it "returns an array of IP addresses" do
          get export_moderator_ip_addrs_path(format: :json), params: { search: { user_name: target.name } }
          expect(response.parsed_body).to be_an(Array)
        end
      end

      context "when searching by user_id" do
        it "returns 200 JSON" do
          get export_moderator_ip_addrs_path(format: :json), params: { search: { user_id: target.id } }
          expect(response).to have_http_status(:ok)
        end

        it "returns an array of IP addresses" do
          get export_moderator_ip_addrs_path(format: :json), params: { search: { user_id: target.id } }
          expect(response.parsed_body).to be_an(Array)
        end
      end

      context "when searching by ip_addr" do
        it "returns 200 and an empty array" do
          get export_moderator_ip_addrs_path(format: :json), params: { search: { ip_addr: "127.0.0.1" } }
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq([])
        end
      end
    end
  end
end
