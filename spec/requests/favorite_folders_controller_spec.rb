# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteFoldersController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:other_member) { create(:user) }

  # ---------------------------------------------------------------------------
  # POST /favorite_folders — create
  # ---------------------------------------------------------------------------

  describe "POST /favorite_folders" do
    context "as anonymous" do
      it "returns 403 for JSON" do
        post favorite_folders_path(format: :json), params: { name: "Memes" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a root-level folder" do
        expect do
          post favorite_folders_path(format: :json), params: { name: "Memes" }
        end.to change(FavoriteFolder, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["name"]).to eq("Memes")
        expect(response.parsed_body["parent_id"]).to be_nil
      end

      it "creates a nested folder under the given parent" do
        parent = create(:favorite_folder, user: member)
        post favorite_folders_path(format: :json), params: { name: "Memes", parent_id: parent.id }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["parent_id"]).to eq(parent.id)
      end

      it "returns 422 when the parent belongs to another user" do
        other_folder = create(:favorite_folder, user: other_member)
        post favorite_folders_path(format: :json), params: { name: "Memes", parent_id: other_folder.id }
        expect(response).to have_http_status(:unprocessable_content)
        expect(FavoriteFolder.count).to eq(1) # only the other member's seed folder
      end

      it "returns 422 on a case-insensitive name collision" do
        create(:favorite_folder, user: member, name: "Memes")
        post favorite_folders_path(format: :json), params: { name: "memes" }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /favorite_folders/:id — update
  # ---------------------------------------------------------------------------

  describe "PATCH /favorite_folders/:id" do
    let(:folder) { create(:favorite_folder, user: member, name: "Old") }

    context "as a member" do
      before { sign_in_as member }

      it "renames the folder" do
        patch favorite_folder_path(folder, format: :json), params: { name: "New" }
        expect(response).to have_http_status(:ok)
        expect(folder.reload.name).to eq("New")
      end

      it "returns 422 on a conflicting rename" do
        create(:favorite_folder, user: member, name: "Taken")
        patch favorite_folder_path(folder, format: :json), params: { name: "taken" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(folder.reload.name).to eq("Old")
      end
    end

    context "as another member" do
      before { sign_in_as other_member }

      it "returns 422 and does not rename another user's folder" do
        patch favorite_folder_path(folder, format: :json), params: { name: "Hijacked" }
        expect(response).to have_http_status(:unprocessable_content)
        expect(folder.reload.name).to eq("Old")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /favorite_folders/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /favorite_folders/:id" do
    context "as a member" do
      before { sign_in_as member }

      it "deletes the folder and redirects to its former parent's listing" do
        parent = create(:favorite_folder, user: member, name: "parent")
        folder = create(:favorite_folder, user: member, name: "child", parent: parent)

        delete favorite_folder_path(folder)
        expect(response).to redirect_to(favorites_path(folder_id: parent.id))
        expect(FavoriteFolder.exists?(folder.id)).to be false
      end

      it "redirects to root when the deleted folder was top-level" do
        folder = create(:favorite_folder, user: member)
        delete favorite_folder_path(folder)
        expect(response).to redirect_to(favorites_path(folder_id: nil))
      end

      it "redirects back with an error and does not delete on a collision" do
        parent = create(:favorite_folder, user: member, name: "parent")
        create(:favorite_folder, user: member, name: "Memes", parent: parent)
        folder = create(:favorite_folder, user: member, name: "child", parent: parent)
        create(:favorite_folder, user: member, name: "memes", parent: folder)

        delete favorite_folder_path(folder)
        expect(response).to redirect_to(favorites_path(folder_id: parent.id))
        expect(flash[:alert]).to match(/already exists/)
        expect(FavoriteFolder.exists?(folder.id)).to be true
      end
    end

    context "as another member" do
      before { sign_in_as other_member }

      it "returns 404 and does not delete another user's folder" do
        folder = create(:favorite_folder, user: member)
        delete favorite_folder_path(folder)
        expect(response).to have_http_status(:not_found)
        expect(FavoriteFolder.exists?(folder.id)).to be true
      end
    end
  end
end
