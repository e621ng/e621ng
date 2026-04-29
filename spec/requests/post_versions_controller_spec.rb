# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostVersionsController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:privileged) { create(:privileged_user) }
  let(:bd_staff) { create(:user, is_bd_staff: true) }

  let(:post_record) { create(:post, tag_string: "tagme edited_tag") }
  # base_version: tags stripped back to "tagme" — version=2 (post creation auto-creates v1)
  let(:base_version) { CurrentUser.scoped(member) { create(:post_version, post: post_record, tags: "tagme") } }
  # edited_version: tags restored to "tagme edited_tag" — version=3
  let(:edited_version) do
    base_version
    CurrentUser.scoped(member) { create(:post_version, post: post_record, tags: "tagme edited_tag") }
  end

  # ---------------------------------------------------------------------------
  # GET /post_versions — index
  # ---------------------------------------------------------------------------

  describe "GET /post_versions" do
    it "returns 200 for anonymous" do
      get post_versions_path
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array" do
      base_version
      get post_versions_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
    end

    context "with search params" do
      let(:other_member) { create(:user) }
      let!(:own_version) { base_version }
      let!(:other_version) { CurrentUser.scoped(other_member) { create(:post_version, post: create(:post)) } }

      it "filters by updater_id" do
        get post_versions_path(format: :json, params: { search: { updater_id: other_member.id } })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(other_version.id)
        expect(ids).not_to include(own_version.id)
      end

      it "filters by post_id" do
        get post_versions_path(format: :json, params: { search: { post_id: post_record.id } })
        ids = response.parsed_body.pluck("id")
        expect(ids).to include(own_version.id)
        expect(ids).not_to include(other_version.id)
      end
    end

    context "as staff" do
      before { sign_in_as create(:janitor_user) }

      it "returns 200" do
        base_version
        get post_versions_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_versions/:id/undo — undo
  # ---------------------------------------------------------------------------

  describe "PUT /post_versions/:id/undo" do
    it "redirects anonymous to login" do
      put undo_post_version_path(edited_version)
      expect(response).to redirect_to(new_session_path)
    end

    context "as a privileged user" do
      before { sign_in_as privileged }

      # FIXME: The undo action lacks respond_with and has no view template, so
      # ApplicationController rescues ActionView::MissingTemplate and returns 406.
      # The post state IS correctly reverted despite the broken response code.
      it "reverts the post to the previous version's tag state" do
        ev = edited_version
        put undo_post_version_path(ev)
        expect(post_record.reload.tag_string).not_to include("edited_tag")
      end
    end

    context "with the auto-created version 1 (not undoable)" do
      before { sign_in_as privileged }

      # post_record creation triggers PostVersion.queue, producing version=1.
      # That version is not undoable (version > 1 is false).
      it "returns 400" do
        v1 = post_record.versions.first
        put undo_post_version_path(v1)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "as a member younger than 7 days (newbie throttle)" do
      # The :user factory defaults created_at to 2 weeks ago; override to within 7 days.
      let(:newbie_member) { create(:user, created_at: 3.days.ago) }

      before { sign_in_as newbie_member }

      it "returns 403" do
        ev = edited_version
        put undo_post_version_path(ev)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_versions/:id/hide — hide
  # ---------------------------------------------------------------------------

  describe "PUT /post_versions/:id/hide" do
    it "redirects anonymous to login" do
      put hide_post_version_path(base_version)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      put hide_post_version_path(base_version)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "sets is_hidden to true" do
        bv = base_version
        put hide_post_version_path(bv)
        expect(bv.reload.is_hidden).to be true
      end

      it "logs a post_version_hide ModAction" do
        bv = base_version
        expect { put hide_post_version_path(bv) }.to change(ModAction, :count).by(1)
        expect(ModAction.last.action).to eq("post_version_hide")
      end

      it "redirects to post versions for the post" do
        bv = base_version
        put hide_post_version_path(bv)
        expect(response).to redirect_to(post_versions_path(search: { post_id: bv.post_id }))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /post_versions/:id/unhide — unhide
  # ---------------------------------------------------------------------------

  describe "PUT /post_versions/:id/unhide" do
    before { base_version.update_columns(is_hidden: true) }

    it "redirects anonymous to login" do
      put unhide_post_version_path(base_version)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a regular member" do
      sign_in_as member
      put unhide_post_version_path(base_version)
      expect(response).to have_http_status(:forbidden)
    end

    context "as bd_staff" do
      before { sign_in_as bd_staff }

      it "sets is_hidden to false" do
        bv = base_version
        put unhide_post_version_path(bv)
        expect(bv.reload.is_hidden).to be false
      end

      it "logs a post_version_unhide ModAction" do
        bv = base_version
        expect { put unhide_post_version_path(bv) }.to change(ModAction, :count).by(1)
        expect(ModAction.last.action).to eq("post_version_unhide")
      end

      it "redirects to post versions for the post" do
        bv = base_version
        put unhide_post_version_path(bv)
        expect(response).to redirect_to(post_versions_path(search: { post_id: bv.post_id }))
      end
    end
  end
end
