# frozen_string_literal: true

require "rails_helper"

RSpec.describe MascotsController do
  include_context "as admin"

  let(:admin)  { create(:admin_user) }
  let(:member) { create(:user) }
  let(:mascot) { create(:mascot) }

  # ---------------------------------------------------------------------------
  # GET /mascots — index (public)
  # ---------------------------------------------------------------------------

  describe "GET /mascots" do
    it "returns 200 for anonymous" do
      get mascots_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a member" do
      sign_in_as member
      get mascots_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get mascots_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get mascots_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes url_path in each JSON record" do
      mascot
      get mascots_path(format: :json)
      expect(response.parsed_body.first).to include("url_path")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /mascots/new — new (admin only)
  # ---------------------------------------------------------------------------

  describe "GET /mascots/new" do
    it "redirects anonymous to the login page" do
      get new_mascot_path
      expect(response).to redirect_to(new_session_path(url: new_mascot_path))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get new_mascot_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_mascot_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /mascots/:id/edit — edit (admin only)
  # ---------------------------------------------------------------------------

  describe "GET /mascots/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_mascot_path(mascot)
      expect(response).to redirect_to(new_session_path(url: edit_mascot_path(mascot)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_mascot_path(mascot)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_mascot_path(mascot)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /mascots — create (admin only)
  # ---------------------------------------------------------------------------

  describe "POST /mascots" do
    # rubocop:disable RSpec/AnyInstance
    before do
      allow_any_instance_of(StorageManager::Local).to receive(:store_mascot)
      allow_any_instance_of(StorageManager::Local).to receive(:delete_mascot)
    end
    # rubocop:enable RSpec/AnyInstance

    let(:mascot_file) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/sample.png"), "image/png") }

    let(:valid_params) do
      {
        mascot: {
          mascot_file:      mascot_file,
          display_name:     "My Mascot",
          background_color: "#012e57",
          foreground_color: "#0f0f0f80",
          artist_url:       "https://www.example.com/artist",
          artist_name:      "Test Artist",
        },
      }
    end

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post mascots_path, params: valid_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post mascots_path(format: :json), params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post mascots_path, params: valid_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "creates a mascot and redirects to mascots_path" do
        expect { post mascots_path, params: valid_params }.to change(Mascot, :count).by(1)
        expect(response).to redirect_to(mascots_path)
      end

      it "sets the creator to the signed-in admin" do
        post mascots_path, params: valid_params
        expect(Mascot.last.creator).to eq(admin)
      end

      it "logs a mascot_create ModAction" do
        post mascots_path, params: valid_params
        expect(ModAction.last.action).to eq("mascot_create")
        expect(ModAction.last[:values]).to include("id" => Mascot.last.id)
      end

      context "with missing mascot_file" do
        let(:invalid_params) { { mascot: valid_params[:mascot].except(:mascot_file) } }

        it "does not create a mascot" do
          expect { post mascots_path, params: invalid_params }.not_to change(Mascot, :count)
        end

        it "does not log a ModAction" do
          expect { post mascots_path, params: invalid_params }.not_to change(ModAction, :count)
        end

        it "re-renders the new form" do
          post mascots_path, params: invalid_params
          expect(response).to have_http_status(:ok)
        end
      end

      context "with a blank display_name" do
        let(:invalid_params) { { mascot: valid_params[:mascot].merge(display_name: "") } }

        it "does not create a mascot" do
          expect { post mascots_path, params: invalid_params }.not_to change(Mascot, :count)
        end

        it "does not log a ModAction" do
          expect { post mascots_path, params: invalid_params }.not_to change(ModAction, :count)
        end

        it "re-renders the new form" do
          post mascots_path, params: invalid_params
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /mascots/:id — update (admin only)
  # ---------------------------------------------------------------------------

  describe "PATCH /mascots/:id" do
    let(:update_params) { { mascot: { display_name: "Renamed Mascot", artist_name: "New Artist" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch mascot_path(mascot), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch mascot_path(mascot, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch mascot_path(mascot), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "updates the mascot and redirects to mascots_path" do
        patch mascot_path(mascot), params: update_params
        expect(mascot.reload.display_name).to eq("Renamed Mascot")
        expect(response).to redirect_to(mascots_path)
      end

      it "logs a mascot_update ModAction" do
        patch mascot_path(mascot), params: update_params
        expect(ModAction.last.action).to eq("mascot_update")
        expect(ModAction.last[:values]).to include("id" => mascot.id)
      end

      context "with a blank display_name" do
        let(:bad_params) { { mascot: { display_name: "" } } }

        it "does not persist the change" do
          original = mascot.display_name
          patch mascot_path(mascot), params: bad_params
          expect(mascot.reload.display_name).to eq(original)
        end

        it "does not log a ModAction" do
          expect { patch mascot_path(mascot), params: bad_params }.not_to change(ModAction, :count)
        end

        it "re-renders the edit form" do
          patch mascot_path(mascot), params: bad_params
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /mascots/:id — destroy (admin only)
  # ---------------------------------------------------------------------------

  describe "DELETE /mascots/:id" do
    it "redirects anonymous to the login page" do
      delete mascot_path(mascot)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      delete mascot_path(mascot)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "destroys the mascot" do
        mascot_id = mascot.id
        expect { delete mascot_path(mascot) }.to change(Mascot, :count).by(-1)
        expect(Mascot.find_by(id: mascot_id)).to be_nil
      end

      it "logs a mascot_delete ModAction" do
        mascot_id = mascot.id
        delete mascot_path(mascot)
        expect(ModAction.last.action).to eq("mascot_delete")
        expect(ModAction.last[:values]).to include("id" => mascot_id)
      end

      it "redirects to mascots_path" do
        delete mascot_path(mascot)
        expect(response).to redirect_to(mascots_path)
      end
    end
  end
end
