# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::WikiRefsController do
  include_context "as admin"

  let(:staff_wiki) { create(:staff_wiki) }
  let(:member)     { create(:user) }
  let(:staff)      { create(:staff_user) }

  # ---------------------------------------------------------------------------
  # POST /staff/wikis/:wiki_id/references
  # ---------------------------------------------------------------------------

  describe "POST create" do
    let(:user)   { create(:user) }
    let(:params) { { staff_wiki_ref: { related_type: "User", related_id: user.id } } }

    it "redirects anonymous to the login page" do
      expect { post staff_wiki_references_path(staff_wiki), params: params }.not_to change(StaffWikiRef, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      expect { post staff_wiki_references_path(staff_wiki), params: params }.not_to change(StaffWikiRef, :count)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a staff member" do
      before { sign_in_as staff }

      it "creates the reference" do
        expect { post staff_wiki_references_path(staff_wiki), params: params }.to change { staff_wiki.references.count }.by(1)
        expect(staff_wiki.references.last.related).to eq(user)
        expect(response).to redirect_to(staff_wiki)
        expect(flash[:notice]).to eq("Reference added")
      end

      it "rejects a duplicate reference" do
        create(:staff_wiki_ref, staff_wiki: staff_wiki, related: user)
        expect { post staff_wiki_references_path(staff_wiki), params: params }.not_to change(StaffWikiRef, :count)
        expect(response).to redirect_to(staff_wiki)
        expect(flash[:alert]).to include("already referenced")
      end

      it "rejects a related type outside the allowed list" do
        target = create(:post)
        expect do
          post staff_wiki_references_path(staff_wiki), params: { staff_wiki_ref: { related_type: "Post", related_id: target.id } }
        end.not_to change(StaffWikiRef, :count)
        expect(flash[:alert]).to include("Related type")
      end

      it "rejects a related record that does not exist" do
        expect do
          post staff_wiki_references_path(staff_wiki), params: { staff_wiki_ref: { related_type: "User", related_id: 0 } }
        end.not_to change(StaffWikiRef, :count)
        expect(flash[:alert]).to include("does not exist")
      end

      it "returns 404 for an unknown wiki" do
        post staff_wiki_references_path(0), params: params
        expect(response).to have_http_status(:not_found)
      end

      it "returns 400 when the staff_wiki_ref params are missing" do
        post staff_wiki_references_path(staff_wiki)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /staff/wikis/:wiki_id/references/:id
  # ---------------------------------------------------------------------------

  describe "DELETE destroy" do
    let!(:ref) { create(:staff_wiki_ref, staff_wiki: staff_wiki) }

    it "redirects anonymous to the login page" do
      expect { delete staff_wiki_reference_path(staff_wiki, ref) }.not_to change(StaffWikiRef, :count)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a non-staff member" do
      sign_in_as member
      expect { delete staff_wiki_reference_path(staff_wiki, ref) }.not_to change(StaffWikiRef, :count)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a staff member" do
      before { sign_in_as staff }

      it "removes the reference" do
        expect { delete staff_wiki_reference_path(staff_wiki, ref) }.to change(StaffWikiRef, :count).by(-1)
        expect(response).to redirect_to(staff_wiki)
        expect(flash[:notice]).to eq("Reference removed")
      end

      it "returns 404 for a reference that belongs to another wiki" do
        other_ref = create(:staff_wiki_ref)
        expect { delete staff_wiki_reference_path(staff_wiki, other_ref) }.not_to change(StaffWikiRef, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

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
