# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailBlacklistsController do
  include_context "as admin"

  let(:member)    { create(:user) }
  let(:admin)     { create(:admin_user) }
  let(:blacklist) { create(:email_blacklist) }

  # ---------------------------------------------------------------------------
  # GET /email_blacklists — index
  # ---------------------------------------------------------------------------

  describe "GET /email_blacklists" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        get email_blacklists_path
        expect(response).to redirect_to(new_session_path(url: email_blacklists_path))
      end

      it "returns 403 for JSON" do
        get email_blacklists_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      get email_blacklists_path
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "returns 200" do
        get email_blacklists_path
        expect(response).to have_http_status(:ok)
      end

      it "returns a JSON array" do
        get email_blacklists_path(format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to be_an(Array)
      end

      context "with multiple blacklist entries" do
        let!(:spam_entry)  { create(:email_blacklist, domain: "spam.example.com", reason: "known spammer") }
        let!(:other_entry) { create(:email_blacklist, domain: "other.example.com", reason: "other reason") }

        it "filters by domain" do
          get email_blacklists_path(format: :json, search: { domain: "spam.example.com" })
          ids = response.parsed_body.pluck("id")
          expect(ids).to include(spam_entry.id)
          expect(ids).not_to include(other_entry.id)
        end

        it "filters by reason" do
          get email_blacklists_path(format: :json, search: { reason: "known spammer" })
          ids = response.parsed_body.pluck("id")
          expect(ids).to include(spam_entry.id)
          expect(ids).not_to include(other_entry.id)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /email_blacklists/new — new
  # ---------------------------------------------------------------------------

  describe "GET /email_blacklists/new" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        get new_email_blacklist_path
        expect(response).to redirect_to(new_session_path(url: new_email_blacklist_path))
      end

      it "returns 403 for JSON" do
        get new_email_blacklist_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_email_blacklist_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_email_blacklist_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /email_blacklists — create
  # ---------------------------------------------------------------------------

  describe "POST /email_blacklists" do
    let(:valid_params) { { email_blacklist: { domain: "newspam.example.com", reason: "spam domain" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post email_blacklists_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post email_blacklists_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post email_blacklists_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates an entry and redirects to the index" do
        expect { post email_blacklists_path, params: valid_params }.to change(EmailBlacklist, :count).by(1)
        expect(response).to redirect_to(email_blacklists_path)
      end

      it "creates an entry via JSON and returns 201" do
        post email_blacklists_path(format: :json), params: valid_params
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include("id" => EmailBlacklist.last.id, "domain" => "newspam.example.com")
      end

      it "re-renders the form when domain is blank" do
        expect do
          post email_blacklists_path, params: { email_blacklist: { domain: "", reason: "spam" } }
        end.not_to change(EmailBlacklist, :count)
        expect(response).to have_http_status(:ok)
      end

      it "re-renders the form when domain is a duplicate" do
        blacklist
        expect do
          post email_blacklists_path, params: { email_blacklist: { domain: blacklist.domain, reason: "duplicate" } }
        end.not_to change(EmailBlacklist, :count)
        expect(response).to have_http_status(:ok)
      end

      it "treats domain duplicates case-insensitively" do
        blacklist
        expect do
          post email_blacklists_path, params: { email_blacklist: { domain: blacklist.domain.upcase, reason: "dup" } }
        end.not_to change(EmailBlacklist, :count)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /email_blacklists/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /email_blacklists/:id" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        delete email_blacklist_path(blacklist)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete email_blacklist_path(blacklist, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete email_blacklist_path(blacklist)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "destroys the entry and redirects to the index" do
        entry_id = blacklist.id
        expect { delete email_blacklist_path(blacklist) }.to change(EmailBlacklist, :count).by(-1)
        expect(EmailBlacklist.find_by(id: entry_id)).to be_nil
        expect(response).to redirect_to(email_blacklists_path)
      end
    end
  end
end
