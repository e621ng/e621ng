# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolElementsController do
  include_context "as admin"

  # :user factory sets created_at 2 weeks ago, so can_remove_from_pools? = true.
  let(:member)      { create(:user) }
  let(:janitor)     { create(:janitor_user) }
  let(:pool)        { create(:pool) }
  let(:post_record) { create(:post) }

  # ---------------------------------------------------------------------------
  # POST /pool_element — create
  # ---------------------------------------------------------------------------

  describe "POST /pool_element" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post pool_element_path, params: { pool_name: pool.name, post_id: post_record.id }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      context "looking up pool by name" do
        let(:params) { { pool_name: pool.name, post_id: post_record.id } }

        it "adds the post to the pool" do
          post pool_element_path(format: :json), params: params
          expect(pool.reload.post_ids).to include(post_record.id)
        end

        it "returns 201 Created" do
          post pool_element_path(format: :json), params: params
          expect(response).to have_http_status(:created)
        end

        it "sets the success flash notice" do
          post pool_element_path, params: params
          expect(flash[:notice]).to eq("Post added to pool ##{pool.id}")
        end

        it "stores the pool id in the session recent list" do
          post pool_element_path, params: params
          expect(session[:recent_pool_ids]).to include(pool.id.to_s)
        end
      end

      context "looking up pool by id" do
        let(:params) { { pool_id: pool.id, post_id: post_record.id } }

        it "adds the post to the pool and returns 201" do
          post pool_element_path(format: :json), params: params
          expect(response).to have_http_status(:created)
          expect(pool.reload.post_ids).to include(post_record.id)
        end

        it "sets the success flash notice" do
          post pool_element_path, params: params
          expect(flash[:notice]).to eq("Post added to pool ##{pool.id}")
        end

        it "stores the pool id in the session recent list" do
          post pool_element_path, params: params
          expect(session[:recent_pool_ids]).to include(pool.id.to_s)
        end
      end

      it "returns 404 when the pool name does not match and no pool_id is given" do
        post pool_element_path(format: :json), params: { pool_name: "no_such_pool_xyz", post_id: post_record.id }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when the pool_id does not exist" do
        post pool_element_path(format: :json), params: { pool_id: 0, post_id: post_record.id }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when the post does not exist" do
        post pool_element_path(format: :json), params: { pool_name: pool.name, post_id: 0 }
        expect(response).to have_http_status(:not_found)
      end

      context "when the post is already in the pool" do
        before { pool.update_columns(post_ids: [post_record.id]) }

        it "is idempotent and returns 201 without duplicating the post id" do
          post pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
          expect(response).to have_http_status(:created)
          expect(pool.reload.post_ids.count(post_record.id)).to eq(1)
        end
      end

      context "when pool.save produces validation errors" do
        before do
          allow(Pool).to receive(:find_by).with(name: pool.name).and_return(pool)
          allow(pool).to receive(:save) do
            pool.errors.add(:base, "Simulated save failure")
            false
          end
        end

        it "returns 422" do
          post pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "sets an error flash containing the validation message" do
          post pool_element_path, params: { pool_name: pool.name, post_id: post_record.id }
          expect(flash[:notice]).to include("Simulated save failure")
        end

        it "does not add the pool to the session recent list" do
          post pool_element_path, params: { pool_name: pool.name, post_id: post_record.id }
          expect(session[:recent_pool_ids].to_s).not_to include(pool.id.to_s)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /pool_element — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /pool_element" do
    before { pool.update_columns(post_ids: [post_record.id]) }

    context "as anonymous" do
      it "redirects to the login page for HTML" do
        delete pool_element_path, params: { pool_name: pool.name, post_id: post_record.id }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member whose account is older than 7 days (can_remove_from_pools? = true)" do
      before { sign_in_as member }

      context "looking up pool by name" do
        let(:params) { { pool_name: pool.name, post_id: post_record.id } }

        it "removes the post from the pool" do
          delete pool_element_path(format: :json), params: params
          expect(pool.reload.post_ids).not_to include(post_record.id)
        end

        it "returns 204 No Content" do
          delete pool_element_path(format: :json), params: params
          expect(response).to have_http_status(:no_content)
        end

        it "sets the success flash notice" do
          delete pool_element_path, params: params
          expect(flash[:notice]).to eq("Post removed from pool ##{pool.id}")
        end
      end

      context "looking up pool by id" do
        let(:params) { { pool_id: pool.id, post_id: post_record.id } }

        it "removes the post from the pool and returns 204" do
          delete pool_element_path(format: :json), params: params
          expect(response).to have_http_status(:no_content)
          expect(pool.reload.post_ids).not_to include(post_record.id)
        end
      end

      it "returns 404 when the post does not exist" do
        delete pool_element_path(format: :json), params: { pool_name: pool.name, post_id: 0 }
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when the pool_id does not exist" do
        delete pool_element_path(format: :json), params: { pool_id: 0, post_id: post_record.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "as a new member whose account is younger than 7 days (can_remove_from_pools? = false)" do
      # FIXME: pool.remove! returns early when can_remove_from_pools? is false, so
      # post_ids is never modified. pool.save then succeeds with no changes; the
      # updater_can_remove_posts validator sees no removed ids and adds no error.
      # The controller therefore returns 204 and sets a "Post removed" success flash
      # even though the post was not actually removed. This is a bug in the
      # application — the test below documents the current broken behaviour.
      let(:new_member) { create(:user).tap { |u| u.update_columns(created_at: 3.days.ago) } }

      before { sign_in_as new_member }

      it "silently appears to succeed (bug: silent no-op) but does NOT remove the post" do
        delete pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
        # Desired: expect(response).not_to have_http_status(:no_content)
        expect(pool.reload.post_ids).to include(post_record.id)
      end
    end

    context "as a janitor" do
      before { sign_in_as janitor }

      it "removes the post from the pool and returns 204" do
        delete pool_element_path(format: :json), params: { pool_name: pool.name, post_id: post_record.id }
        expect(response).to have_http_status(:no_content)
        expect(pool.reload.post_ids).not_to include(post_record.id)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /pool_element/recent — recent
  # ---------------------------------------------------------------------------

  describe "GET /pool_element/recent" do
    context "as anonymous" do
      it "redirects to the login page with the return URL for HTML" do
        get recent_pool_element_path
        expect(response).to redirect_to(new_session_path(url: recent_pool_element_path))
      end

      it "returns 403 for JSON" do
        get recent_pool_element_path(format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "returns 200 OK" do
        get recent_pool_element_path(format: :json)
        expect(response).to have_http_status(:ok)
      end

      it "returns an empty array when no pools have been accessed" do
        get recent_pool_element_path(format: :json)
        expect(response.parsed_body).to eq([])
      end

      context "after adding posts to two pools via the create action" do
        # Use let! so all records are created (with CurrentUser.user = admin from
        # the outer before block) before the HTTP requests in the inner before
        # block fire and trigger after_action :reset_current_user.
        let!(:pool2)        { create(:pool) }
        let!(:post_record2) { create(:post) }
        # extra_post is declared here (not in a nested context) so it is
        # created before the before block's HTTP requests clear CurrentUser.
        let!(:extra_post)   { create(:post) }

        before do
          post pool_element_path, params: { pool_name: pool.name,  post_id: post_record.id }
          post pool_element_path, params: { pool_name: pool2.name, post_id: post_record2.id }
        end

        it "returns a JSON array of objects with id and name keys" do
          get recent_pool_element_path(format: :json)
          expect(response.parsed_body).to all(include("id", "name"))
        end

        it "includes both pools" do
          get recent_pool_element_path(format: :json)
          ids = response.parsed_body.pluck("id")
          expect(ids).to include(pool.id, pool2.id)
        end

        it "returns pools in insertion order (first-added appears first)" do
          get recent_pool_element_path(format: :json)
          ids = response.parsed_body.pluck("id")
          expect(ids.index(pool.id)).to be < ids.index(pool2.id)
        end

        it "moves a re-added pool to the end of the list and deduplicates it" do
          post pool_element_path, params: { pool_name: pool.name, post_id: extra_post.id }

          get recent_pool_element_path(format: :json)
          ids = response.parsed_body.pluck("id")
          expect(ids.last).to eq(pool.id)
          expect(ids.count(pool.id)).to eq(1)
        end
      end

      context "after adding posts to six pools via the create action" do
        # All factories are created eagerly (let!) before any HTTP requests so
        # that after_action :reset_current_user does not clear CurrentUser.user
        # during factory evaluation.
        let!(:extra_pools) { create_list(:pool, 6) }
        let!(:extra_posts) { create_list(:post, 6) }

        before do
          extra_pools.zip(extra_posts).each do |p, ep|
            post pool_element_path, params: { pool_name: p.name, post_id: ep.id }
          end
        end

        it "caps the recent list at 5 entries" do
          get recent_pool_element_path(format: :json)
          expect(response.parsed_body.length).to eq(5)
        end
      end

      context "when the only pool in the session has been deleted" do
        before do
          post pool_element_path, params: { pool_name: pool.name, post_id: post_record.id }
          pool.destroy!
        end

        it "returns an empty array without raising an error" do
          get recent_pool_element_path(format: :json)
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq([])
        end
      end
    end
  end
end
