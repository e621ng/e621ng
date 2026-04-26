# frozen_string_literal: true

require "rails_helper"

#          pools GET    /pools(.:format)            pools#index
#                POST   /pools(.:format)            pools#create
#       new_pool GET    /pools/new(.:format)        pools#new
#      edit_pool GET    /pools/:id/edit(.:format)   pools#edit
#           pool GET    /pools/:id(.:format)        pools#show
#                PUT    /pools/:id(.:format)        pools#update
#                DELETE /pools/:id(.:format)        pools#destroy
#    revert_pool PUT    /pools/:id/revert(.:format) pools#revert
#  gallery_pools GET    /pools/gallery(.:format)    pools#gallery

RSpec.describe PoolsController do
  let(:user)    { create(:user) }
  let(:admin)   { create(:admin_user) }
  let(:janitor) { create(:janitor_user) }
  let(:pool)    { CurrentUser.scoped(admin) { create(:pool) } }

  describe "#index" do
    before { pool }

    it "renders HTML" do
      get pools_path
      expect(response).to have_http_status(:ok)
    end

    it "renders JSON and includes the pool" do
      get pools_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("id")).to include(pool.id)
    end

    it "filters by name_matches" do
      other_pool = CurrentUser.scoped(admin) { create(:pool) }
      get pools_path(format: :json), params: { search: { name_matches: pool.name } }
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(pool.id)
      expect(ids).not_to include(other_pool.id)
    end

    it "filters by category" do
      series_pool     = CurrentUser.scoped(admin) { create(:series_pool) }
      collection_pool = CurrentUser.scoped(admin) { create(:collection_pool) }
      get pools_path(format: :json), params: { search: { category: "series" } }
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(series_pool.id)
      expect(ids).not_to include(collection_pool.id)
    end
  end

  describe "#show" do
    it "renders HTML" do
      get pool_path(pool)
      expect(response).to have_http_status(:ok)
    end

    it "renders JSON with the pool id" do
      get pool_path(pool, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(pool.id)
    end

    it "returns 404 for a nonexistent pool" do
      get pool_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "#gallery" do
    before { pool }

    it "renders HTML for anonymous users" do
      get gallery_pools_path
      expect(response).to have_http_status(:ok)
    end

    it "renders HTML for a member" do
      get_auth gallery_pools_path, user
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#new" do
    it "renders for a member" do
      get_auth new_pool_path, user
      expect(response).to have_http_status(:ok)
    end

    it "redirects anonymous users to login" do
      get new_pool_path
      expect(response).to redirect_to(new_session_path(url: new_pool_path))
    end
  end

  describe "#create" do
    context "as admin" do
      it "creates a pool" do
        expect do
          post_auth pools_path, admin, params: { pool: { name: "brand_new_pool", description: "A test pool", category: "series" } }
        end.to change(Pool, :count).by(1)
      end

      it "sets a flash notice on success" do
        post_auth pools_path, admin, params: { pool: { name: "flash_notice_pool", category: "series" } }
        expect(flash[:notice]).to eq("Pool created")
      end

      it "redirects to the new pool on success" do
        post_auth pools_path, admin, params: { pool: { name: "redirect_pool", category: "series" } }
        expect(response).to redirect_to(pool_path(Pool.last))
      end

      it "does not create a pool with a duplicate name and sets an error flash" do
        existing = pool
        expect do
          post_auth pools_path, admin, params: { pool: { name: existing.name, category: "series" } }
        end.not_to change(Pool, :count)
        expect(flash[:notice]).to include("Name")
      end
    end

    it "redirects anonymous users to login without creating a pool" do
      expect do
        post pools_path, params: { pool: { name: "anon_pool", category: "series" } }
      end.not_to change(Pool, :count)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "#edit" do
    it "renders for a member" do
      get_auth edit_pool_path(pool), user
      expect(response).to have_http_status(:ok)
    end

    it "redirects anonymous users to login" do
      get edit_pool_path(pool)
      expect(response).to redirect_to(new_session_path(url: edit_pool_path(pool)))
    end
  end

  describe "#update" do
    context "as admin" do
      it "updates description and sets flash notice" do
        put_auth pool_path(pool), admin, params: { pool: { description: "updated description" } }
        expect(pool.reload.description).to eq("updated description")
        expect(flash[:notice]).to eq("Pool updated")
      end

      it "updates the pool name" do
        put_auth pool_path(pool), admin, params: { pool: { name: "renamed_pool" } }
        expect(pool.reload.name).to eq("renamed_pool")
      end

      it "redirects to the pool on success" do
        put_auth pool_path(pool), admin, params: { pool: { description: "desc" } }
        expect(response).to redirect_to(pool_path(pool))
      end
    end

    it "redirects anonymous users to login without updating" do
      original_description = pool.description
      put pool_path(pool), params: { pool: { description: "hacked" } }
      expect(response).to redirect_to(new_session_path)
      expect(pool.reload.description).to eq(original_description)
    end
  end

  describe "#destroy" do
    it "destroys the pool as janitor and redirects to the index" do
      pool
      expect do
        delete_auth pool_path(pool), janitor
      end.to change(Pool, :count).by(-1)
      expect(response).to redirect_to(pools_path)
    end

    it "sets a flash notice on successful destruction" do
      delete_auth pool_path(pool), janitor
      expect(flash[:notice]).to eq("Pool deleted")
    end

    it "returns 403 for a member" do
      pool
      expect do
        delete_auth pool_path(pool), user
      end.not_to change(Pool, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous users to login without destroying" do
      pool
      expect do
        delete pool_path(pool)
      end.not_to change(Pool, :count)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "#revert" do
    let!(:pool) { CurrentUser.scoped(admin) { create(:pool, description: "original") } }
    let!(:initial_version) { pool.versions.order(:id).first }

    before do
      CurrentUser.scoped(admin) { pool.update!(description: "updated") }
    end

    it "reverts the pool to a previous version as admin" do
      put_auth revert_pool_path(pool), admin, params: { version_id: initial_version.id }
      expect(pool.reload.description).to eq("original")
      expect(response).to redirect_to(pool_path(pool))
    end

    it "redirects anonymous users to login" do
      put revert_pool_path(pool), params: { version_id: initial_version.id }
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "lockdown" do
    before { allow(Security::Lockdown).to receive(:pools_disabled?).and_return(true) }

    it "blocks create for a non-staff member" do
      expect do
        post_auth pools_path, user, params: { pool: { name: "lockdown_pool", category: "series" } }
      end.not_to change(Pool, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "allows create for a staff member (janitor)" do
      expect do
        post_auth pools_path, janitor, params: { pool: { name: "staff_pool", category: "series" } }
      end.to change(Pool, :count).by(1)
    end
  end
end
