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

    describe "sortable list" do
      def sort_link(column)
        Nokogiri::HTML(response.body).at_css(".index-list-header a.pl-#{column}")
      end

      def sort_link_order(column)
        uri = URI.parse(sort_link(column)["href"])
        Rack::Utils.parse_nested_query(uri.query).dig("search", "order")
      end

      # The direction the list is sorted by this column, or nil when it is sorted by another one.
      def sorted(column)
        link = sort_link(column)
        return nil unless link["aria-current"] == "true"
        link["aria-label"][/sorted (\w+)\z/, 1]
      end

      it "renders the pool's id, post count and update time" do
        get pools_path
        item = Nokogiri::HTML(response.body).at_css("li#pool-#{pool.id}.pool-list-item")
        expect(item.at_css(".pl-id").text.strip).to eq("##{pool.id}")
        expect(item.at_css(".pl-name a")["href"]).to eq(pool_path(pool))
        expect(item.at_css(".pl-posts").text.strip).to eq("#{pool.post_count} #{'post'.pluralize(pool.post_count)}")
        expect(Time.zone.parse(item.at_css(".pl-updated time")["datetime"])).to eq(pool.updated_at.change(sec: 0))
      end

      it "marks the updated column as sorted by default, and its link reverses the order" do
        get pools_path
        expect(sorted(:updated)).to eq("descending")
        expect(sort_link_order(:updated)).to eq("updated_at_asc")
        expect(sorted(:name)).to be_nil
        expect(sort_link_order(:name)).to eq("name")
      end

      it "reverses the order of the sorted column" do
        get pools_path, params: { search: { order: "name" } }
        expect(sorted(:name)).to eq("ascending")
        expect(sort_link_order(:name)).to eq("name_desc")
        expect(sorted(:updated)).to be_nil
        expect(sort_link_order(:updated)).to eq("updated_at")
      end

      it "treats the created_at order as the id column sorted descending" do
        get pools_path, params: { search: { order: "created_at" } }
        expect(sorted(:id)).to eq("descending")
        expect(sort_link_order(:id)).to eq("id_asc")
      end

      it "marks the id column as sorted on sequential pages, which ignore the order" do
        get pools_path, params: { search: { order: "name" }, page: "b#{pool.id + 1}" }
        expect(sorted(:id)).to eq("descending")
        expect(sorted(:name)).to be_nil
      end

      it "offers every header order in the search form, so submitting it keeps the order" do
        get pools_path
        options = Nokogiri::HTML(response.body).css("select#search_order option").pluck("value")
        expect(options).to include(*PoolsHelper::POOL_INDEX_SORTS.values.flat_map(&:keys))
      end

      it "keeps the search form closed when the list is only sorted" do
        get pools_path, params: { search: { order: "name" } }
        expect(Nokogiri::HTML(response.body).at_css("#searchform")["style"]).to include("display:none")
      end

      it "opens the search form when the list is also filtered" do
        get pools_path, params: { search: { order: "name", name_matches: "foo" } }
        expect(Nokogiri::HTML(response.body).at_css("#searchform")["style"].to_s).not_to include("display:none")
      end

      it "still opens the gallery's search form for a sort, as the gallery has no sort links" do
        get gallery_pools_path, params: { search: { order: "name" } }
        expect(Nokogiri::HTML(response.body).at_css("#searchform")["style"].to_s).not_to include("display:none")
      end

      it "keeps the other search params and drops the page" do
        get pools_path, params: { search: { name_matches: "foo", order: "post_count" }, page: 2, limit: 10 }
        params = Rack::Utils.parse_nested_query(URI.parse(sort_link(:posts)["href"]).query)
        expect(params).to eq("search" => { "name_matches" => "foo", "order" => "post_count_asc" }, "limit" => "10")
      end
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
      sign_in_as user
      get gallery_pools_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#new" do
    it "renders for a member" do
      sign_in_as user
      get new_pool_path
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
          sign_in_as admin
          post pools_path, params: { pool: { name: "brand_new_pool", description: "A test pool", category: "series" } }
        end.to change(Pool, :count).by(1)
      end

      it "sets a flash notice on success" do
        sign_in_as admin
        post pools_path, params: { pool: { name: "flash_notice_pool", category: "series" } }
        expect(flash[:notice]).to eq("Pool created")
      end

      it "redirects to the new pool on success" do
        sign_in_as admin
        post pools_path, params: { pool: { name: "redirect_pool", category: "series" } }
        expect(response).to redirect_to(pool_path(Pool.last))
      end

      it "does not create a pool with a duplicate name and sets an error flash" do
        existing = pool
        expect do
          sign_in_as admin
          post pools_path, params: { pool: { name: existing.name, category: "series" } }
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
      sign_in_as user
      get edit_pool_path(pool)
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
        sign_in_as admin
        put pool_path(pool), params: { pool: { description: "updated description" } }
        expect(pool.reload.description).to eq("updated description")
        expect(flash[:notice]).to eq("Pool updated")
      end

      it "updates the pool name" do
        sign_in_as admin
        put pool_path(pool), params: { pool: { name: "renamed_pool" } }
        expect(pool.reload.name).to eq("renamed_pool")
      end

      it "redirects to the pool on success" do
        sign_in_as admin
        put pool_path(pool), params: { pool: { description: "desc" } }
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
        sign_in_as janitor
        delete pool_path(pool)
      end.to change(Pool, :count).by(-1)
      expect(response).to redirect_to(pools_path)
    end

    it "sets a flash notice on successful destruction" do
      sign_in_as janitor
      delete pool_path(pool)
      expect(flash[:notice]).to eq("Pool deleted")
    end

    it "returns 403 for a member" do
      pool
      expect do
        sign_in_as user
        delete pool_path(pool)
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
      sign_in_as admin
      put revert_pool_path(pool), params: { version_id: initial_version.id }
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
        sign_in_as user
        post pools_path, params: { pool: { name: "lockdown_pool", category: "series" } }
      end.not_to change(Pool, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "allows create for a staff member (janitor)" do
      expect do
        sign_in_as janitor
        post pools_path, params: { pool: { name: "staff_pool", category: "series" } }
      end.to change(Pool, :count).by(1)
    end
  end
end
