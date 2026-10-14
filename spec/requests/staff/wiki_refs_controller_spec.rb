# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::WikiRefsController do
  include_context "as admin"

  let(:staff_wiki) { create(:staff_wiki) }
  let(:member)     { create(:user) }
  let(:staff)      { create(:staff_user) }

  # ---------------------------------------------------------------------------
  # POST /staff/wikis/:wiki_id/references/bulk_create
  # ---------------------------------------------------------------------------

  describe "POST bulk_create" do
    let(:user)   { create(:user) }
    let(:artist) { create(:artist) }

    it "returns 403 for a non-staff member" do
      sign_in_as member
      post bulk_create_staff_wiki_references_path(staff_wiki), params: { urls: "" }
      expect(response).to have_http_status(:forbidden)
    end

    context "as a staff member" do
      before { sign_in_as staff }

      it "creates references for each valid URL" do
        urls = "https://e621.net/users/#{user.id}\nhttps://e621.net/artists/#{artist.id}"
        expect do
          post bulk_create_staff_wiki_references_path(staff_wiki), params: { urls: urls }
        end.to change { staff_wiki.references.count }.by(2)
        expect(response).to redirect_to(staff_wiki)
      end

      it "skips duplicates and reports them" do
        create(:staff_wiki_ref, staff_wiki: staff_wiki, related: user)
        urls = "https://e621.net/users/#{user.id}"
        expect do
          post bulk_create_staff_wiki_references_path(staff_wiki), params: { urls: urls }
        end.not_to change(staff_wiki.references, :count)
        expect(flash[:alert]).to include("already existed")
      end

      it "creates valid references and reports unparseable input" do
        urls = "https://e621.net/users/#{user.id}\nnot-a-url"
        expect do
          post bulk_create_staff_wiki_references_path(staff_wiki), params: { urls: urls }
        end.to change { staff_wiki.references.count }.by(1)
        expect(flash[:notice]).to include("could not be parsed")
        expect(flash[:notice]).to include("not-a-url")
      end
    end
  end
end
