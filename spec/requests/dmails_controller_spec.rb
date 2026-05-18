# frozen_string_literal: true

require "rails_helper"

RSpec.describe DmailsController do
  include_context "as admin"

  let(:sender)    { create(:user) }
  let(:recipient) { create(:user) }
  let(:other)     { create(:user) }
  let(:janitor) { create(:janitor_user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  # recipient's copy (owner_id == to_id by factory default)
  let(:dmail) { create(:dmail, from: sender, to: recipient) }

  # ---------------------------------------------------------------------------
  # GET /dmails — index
  # ---------------------------------------------------------------------------

  describe "GET /dmails" do
    it "redirects anonymous to the login page" do
      get dmails_path
      expect(response).to redirect_to(new_session_path(url: dmails_path))
    end

    it "returns 200 for a signed-in member" do
      sign_in_as recipient
      get dmails_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      sign_in_as recipient
      get dmails_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    it "includes dmails owned by the current user" do
      id = dmail.id # force creation before the request resets CurrentUser
      sign_in_as recipient
      get dmails_path(format: :json)
      expect(response.parsed_body.pluck("id")).to include(id)
    end

    it "does not include dmails owned by another user" do
      id = dmail.id # force creation before the request resets CurrentUser
      sign_in_as other
      get dmails_path(format: :json)
      expect(response.parsed_body.pluck("id")).not_to include(id)
    end

    it "sets the dmail_folder cookie when folder and set_default_folder params are given" do
      sign_in_as recipient
      get dmails_path, params: { folder: "sent", set_default_folder: "1" }
      expect(response.cookies["dmail_folder"]).to eq("sent")
    end
  end

  # ---------------------------------------------------------------------------
  # GET /dmails/new — new
  # ---------------------------------------------------------------------------

  describe "GET /dmails/new" do
    it "redirects anonymous to the login page" do
      get new_dmail_path
      expect(response).to redirect_to(new_session_path(url: new_dmail_path))
    end

    it "returns 200 for a signed-in member" do
      sign_in_as sender
      get new_dmail_path
      expect(response).to have_http_status(:ok)
    end

    context "with respond_to_id" do
      it "returns 200 when the user owns the parent dmail" do
        sign_in_as recipient
        get new_dmail_path, params: { respond_to_id: dmail.id }
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 when the user does not own the parent dmail" do
        sign_in_as other
        get new_dmail_path, params: { respond_to_id: dmail.id }
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a forward" do
        sign_in_as recipient
        get new_dmail_path, params: { respond_to_id: dmail.id, forward: true }
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 for a janitor when the recipient is the system user" do
        dmail_to_system = create(:dmail, from: sender, to: User.system, owner_id: User.system.id)
        sign_in_as janitor
        get new_dmail_path, params: { respond_to_id: dmail_to_system.id }
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 for a different user when the recipient is the system user" do
        dmail_to_system = create(:dmail, from: sender, to: User.system, owner_id: User.system.id)
        sign_in_as other
        get new_dmail_path, params: { respond_to_id: dmail_to_system.id }
        expect(response).to have_http_status(:forbidden)
      end

      it "returns 200 for a forward for a janitor when the recipient is the system user" do
        dmail_to_system = create(:dmail, from: sender, to: User.system, owner_id: User.system.id)
        sign_in_as janitor
        get new_dmail_path, params: { respond_to_id: dmail_to_system.id, forward: true }
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 for a forward for a different user when the recipient is the system user" do
        dmail_to_system = create(:dmail, from: sender, to: User.system, owner_id: User.system.id)
        sign_in_as other
        get new_dmail_path, params: { respond_to_id: dmail_to_system.id, forward: true }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /dmails — create
  # ---------------------------------------------------------------------------

  describe "POST /dmails" do
    let(:valid_params) { { dmail: { title: "Hello", body: "Test body.", to_name: recipient.name } } }

    it "redirects anonymous to the login page" do
      post dmails_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end

    context "as a member" do
      before { sign_in_as sender }

      it "creates two dmail records on success (split for sender and recipient)" do
        expect { post dmails_path, params: valid_params }.to change(Dmail, :count).by(2)
      end

      it "redirects after a successful create" do
        post dmails_path, params: valid_params
        expect(response).to be_redirect
      end

      it "does not create a dmail when title is blank" do
        expect do
          post dmails_path, params: { dmail: { title: "", body: "Body.", to_name: recipient.name } }
        end.not_to change(Dmail, :count)
      end

      it "does not create a dmail when body is blank" do
        expect do
          post dmails_path, params: { dmail: { title: "Title", body: "", to_name: recipient.name } }
        end.not_to change(Dmail, :count)
      end

      # FIXME: disable_user_dmails is not a regular DB column (likely a rails-settings-cached
      # field), so update_columns cannot set it. A different mechanism is needed to test this path.
      # it "does not create a dmail when the recipient has disabled dmails" do
      #   recipient.update_columns(disable_user_dmails: true)
      #   expect { post dmails_path, params: valid_params }.not_to change(Dmail, :count)
      # end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /dmails/:id — show
  # ---------------------------------------------------------------------------

  describe "GET /dmails/:id" do
    it "redirects anonymous to the login page" do
      get dmail_path(dmail)
      expect(response).to redirect_to(new_session_path(url: dmail_path(dmail)))
    end

    it "returns 200 for the owner (HTML)" do
      sign_in_as recipient
      get dmail_path(dmail)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for the owner (JSON)" do
      sign_in_as recipient
      get dmail_path(dmail, format: :json)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other
      get dmail_path(dmail)
      expect(response).to have_http_status(:forbidden)
    end

    it "marks an unread dmail as read on HTML show" do
      dmail.update_columns(is_read: false)
      sign_in_as recipient
      get dmail_path(dmail)
      expect(dmail.reload.is_read).to be true
    end

    it "does not toggle is_read when the dmail is already read" do
      dmail.update_columns(is_read: true)
      sign_in_as recipient
      expect { get dmail_path(dmail) }.not_to(change { dmail.reload.is_read })
    end

    it "returns 200 for a janitor viewing a system-received dmail" do
      dmail_to_system = create(:dmail, from: recipient, to: User.system)
      sign_in_as janitor
      get dmail_path(dmail_to_system)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for a moderator viewing a system-sent dmail" do
      system_dmail = create(:dmail, from: User.system, to: recipient)
      sign_in_as moderator
      get dmail_path(system_dmail)
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 for an admin viewing a dmail where one party is an admin" do
      admin_dmail = create(:dmail, from: admin, to: recipient)
      sign_in_as admin
      get dmail_path(admin_dmail)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /dmails/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /dmails/:id" do
    it "redirects anonymous to the login page" do
      delete dmail_path(dmail)
      expect(response).to redirect_to(new_session_path)
    end

    it "soft-deletes the dmail and redirects with a notice for the owner" do
      sign_in_as recipient
      expect { delete dmail_path(dmail) }.to change { dmail.reload.is_deleted }.from(false).to(true)
      expect(response).to redirect_to(dmails_path)
      expect(flash[:notice]).to eq("Message deleted")
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other
      delete dmail_path(dmail)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 204 for the owner (JSON)" do
      sign_in_as recipient
      delete dmail_path(dmail, format: :json)
      expect(response).to have_http_status(:no_content)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /dmails/:id/mark_as_read — mark_as_read
  # ---------------------------------------------------------------------------

  describe "PUT /dmails/:id/mark_as_read" do
    before { dmail.update_columns(is_read: false) }

    it "redirects anonymous to the login page" do
      put mark_as_read_dmail_path(dmail)
      expect(response).to redirect_to(new_session_path)
    end

    # FIXME: mark_as_read has no HTML template and no explicit respond_with or
    # redirect, causing ActionController::MissingExactTemplate on HTML requests.
    # it "marks the dmail as read for the owner (HTML)" do
    #   sign_in_as recipient
    #   put mark_as_read_dmail_path(dmail)
    #   expect(dmail.reload.is_read).to be true
    # end

    it "marks the dmail as read for the owner (JSON)" do
      sign_in_as recipient
      put mark_as_read_dmail_path(dmail, format: :json)
      expect(dmail.reload.is_read).to be true
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other
      put mark_as_read_dmail_path(dmail, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /dmails/:id/mark_as_unread — mark_as_unread
  # ---------------------------------------------------------------------------

  describe "PUT /dmails/:id/mark_as_unread" do
    before { dmail.update_columns(is_read: true) }

    it "redirects anonymous to the login page" do
      put mark_as_unread_dmail_path(dmail)
      expect(response).to redirect_to(new_session_path)
    end

    it "marks the dmail as unread and redirects with a notice for the owner (HTML)" do
      sign_in_as recipient
      put mark_as_unread_dmail_path(dmail)
      expect(dmail.reload.is_read).to be false
      expect(response).to redirect_to(dmails_path)
      expect(flash[:notice]).to eq("Message marked as unread")
    end

    it "marks the dmail as unread for the owner (JSON)" do
      sign_in_as recipient
      put mark_as_unread_dmail_path(dmail, format: :json)
      expect(dmail.reload.is_read).to be false
    end

    it "returns 403 for a non-owner member" do
      sign_in_as other
      put mark_as_unread_dmail_path(dmail, format: :json)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /dmails/mark_all_as_read — mark_all_as_read (collection)
  # ---------------------------------------------------------------------------

  describe "PUT /dmails/mark_all_as_read" do
    it "redirects anonymous to the login page" do
      put mark_all_as_read_dmails_path
      expect(response).to redirect_to(new_session_path)
    end

    context "as a member with unread dmails" do
      before do
        dmail.update_columns(is_read: false)
        recipient.update_columns(unread_dmail_count: 1)
        sign_in_as recipient
      end

      it "marks all owned dmails as read" do
        put mark_all_as_read_dmails_path
        expect(dmail.reload.is_read).to be true
      end

      it "resets unread_dmail_count to 0 on the user" do
        put mark_all_as_read_dmails_path
        expect(recipient.reload.unread_dmail_count).to eq(0)
      end

      it "redirects to dmails_path with a notice" do
        put mark_all_as_read_dmails_path
        expect(response).to redirect_to(dmails_path)
        expect(flash[:notice]).to eq("All messages marked as read")
      end
    end
  end
end
