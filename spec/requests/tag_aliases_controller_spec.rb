# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAliasesController do
  before do
    CurrentUser.user    = User.find_by!(name: "admin")
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  let(:member)    { create(:user) }
  let(:admin)     { create(:admin_user) }
  let(:tag_alias) { create(:tag_alias) }

  # ---------------------------------------------------------------------------
  # GET /tag_aliases — index
  # ---------------------------------------------------------------------------

  describe "GET /tag_aliases" do
    it "returns 200 for anonymous" do
      get tag_aliases_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      get tag_aliases_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with aliases of different statuses" do
      let!(:pending_alias) { create(:tag_alias) }
      let!(:active_alias)  { create(:active_tag_alias) }
      let!(:deleted_alias) { create(:deleted_tag_alias) }

      it "filters to pending aliases when search[status]=pending" do
        get tag_aliases_path(format: :json, search: { status: "pending" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(pending_alias.id)
        expect(ids).not_to include(active_alias.id, deleted_alias.id)
      end

      it "filters to active aliases when search[status]=active" do
        get tag_aliases_path(format: :json, search: { status: "active" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(active_alias.id)
        expect(ids).not_to include(pending_alias.id, deleted_alias.id)
      end
    end

    context "with name filtering" do
      let!(:matching)    { create(:tag_alias, antecedent_name: "fluffy_ears", consequent_name: "floppy_ears") }
      let!(:nonmatching) { create(:tag_alias, antecedent_name: "sharp_claws", consequent_name: "pointy_claws") }

      it "matches aliases by antecedent name" do
        get tag_aliases_path(format: :json, search: { name_matches: "fluffy_ears" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(matching.id)
        expect(ids).not_to include(nonmatching.id)
      end

      it "matches aliases by consequent name" do
        get tag_aliases_path(format: :json, search: { name_matches: "floppy_ears" })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(matching.id)
        expect(ids).not_to include(nonmatching.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tag_aliases/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /tag_aliases/:id" do
    it "returns 200 for anonymous" do
      get tag_alias_path(tag_alias)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 JSON including the alias id" do
      get tag_alias_path(tag_alias, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("id" => tag_alias.id)
    end

    it "returns 404 for a non-existent id" do
      get tag_alias_path(0)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /tag_aliases/:id/edit — edit (admin_only)
  # ---------------------------------------------------------------------------

  describe "GET /tag_aliases/:id/edit" do
    it "redirects anonymous to the login page" do
      get edit_tag_alias_path(tag_alias)
      expect(response).to redirect_to(new_session_path(url: edit_tag_alias_path(tag_alias)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get edit_tag_alias_path(tag_alias)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get edit_tag_alias_path(tag_alias)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /tag_aliases/:id — update (admin_only)
  # ---------------------------------------------------------------------------

  describe "PATCH /tag_aliases/:id" do
    let(:update_params) { { tag_alias: { antecedent_name: "updated_ante", consequent_name: "updated_cons" } } }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        patch tag_alias_path(tag_alias), params: update_params
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        patch tag_alias_path(tag_alias, format: :json), params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      patch tag_alias_path(tag_alias), params: update_params
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin" do
      before { sign_in_as admin }

      context "when the alias is pending (editable_by? = true)" do
        let(:pending) { create(:tag_alias) }

        it "updates antecedent_name and consequent_name" do
          patch tag_alias_path(pending), params: { tag_alias: { antecedent_name: "new_ante_tag", consequent_name: "new_cons_tag" } }
          pending.reload
          expect(pending.antecedent_name).to eq("new_ante_tag")
          expect(pending.consequent_name).to eq("new_cons_tag")
        end
      end

      context "when the alias is active (editable_by? = false)" do
        let(:active) { create(:active_tag_alias) }

        it "silently skips the update and leaves attributes unchanged" do
          original_antecedent = active.antecedent_name
          patch tag_alias_path(active), params: { tag_alias: { antecedent_name: "should_not_change" } }
          expect(active.reload.antecedent_name).to eq(original_antecedent)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /tag_aliases/:id — destroy (no before_action; inline deletable_by?)
  # ---------------------------------------------------------------------------

  describe "DELETE /tag_aliases/:id" do
    context "as anonymous" do
      it "redirects HTML to the login page" do
        delete tag_alias_path(tag_alias)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete tag_alias_path(tag_alias, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member who is not the creator" do
      it "returns 403" do
        sign_in_as member
        delete tag_alias_path(tag_alias)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as the creator of a pending alias" do
      let(:creator)       { create(:user) }
      # use update_columns to bypass the before_validation callback that
      # overwrites creator_id with CurrentUser.id
      let(:creator_alias) { create(:tag_alias).tap { |ta| ta.update_columns(creator_id: creator.id) } }

      before { sign_in_as creator }

      it "sets the alias status to deleted" do
        delete tag_alias_path(creator_alias)
        expect(creator_alias.reload.status).to eq("deleted")
      end

      it "redirects to tag_aliases_path" do
        delete tag_alias_path(creator_alias)
        expect(response).to redirect_to(tag_aliases_path)
      end
    end

    context "as admin" do
      before { sign_in_as admin }

      it "sets the alias status to deleted and redirects" do
        delete tag_alias_path(tag_alias)
        expect(tag_alias.reload.status).to eq("deleted")
        expect(response).to redirect_to(tag_aliases_path)
      end

      it "returns 403 when the alias is already deleted" do
        deleted = create(:deleted_tag_alias)
        delete tag_alias_path(deleted)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /tag_aliases/:id/approve — approve (admin_only)
  # ---------------------------------------------------------------------------

  describe "POST /tag_aliases/:id/approve" do
    let(:pending_alias) { create(:tag_alias) }

    context "as anonymous" do
      it "redirects HTML to the login page" do
        post approve_tag_alias_path(pending_alias)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post approve_tag_alias_path(pending_alias, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    it "returns 403 for a member" do
      sign_in_as member
      post approve_tag_alias_path(pending_alias)
      expect(response).to have_http_status(:forbidden)
    end

    context "as admin approving a pending alias with non-DNP tags" do
      before { sign_in_as admin }

      it "sets the alias status to queued" do
        post approve_tag_alias_path(pending_alias)
        expect(pending_alias.reload.status).to eq("queued")
      end

      it "redirects to the tag alias page" do
        post approve_tag_alias_path(pending_alias)
        expect(response).to redirect_to(tag_alias_path(pending_alias))
      end
    end

    context "as admin approving an already-active alias" do
      let(:active_alias) { create(:active_tag_alias) }

      before { sign_in_as admin }

      it "returns 403 because the alias is not approvable" do
        post approve_tag_alias_path(active_alias)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
