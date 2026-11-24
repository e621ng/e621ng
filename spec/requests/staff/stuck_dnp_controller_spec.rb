# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::StuckDnpController do
  include_context "as admin"

  let(:admin)     { create(:admin_user) }
  let(:moderator) { create(:moderator_user) }

  # ---------------------------------------------------------------------------
  # GET /staff/stuck_dnp/new
  # ---------------------------------------------------------------------------

  describe "GET /staff/stuck_dnp/new" do
    it "redirects anonymous to the login page" do
      get new_staff_stuck_dnp_path
      expect(response).to redirect_to(new_session_path(url: new_staff_stuck_dnp_path))
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      get new_staff_stuck_dnp_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an admin" do
      sign_in_as admin
      get new_staff_stuck_dnp_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/stuck_dnp
  # ---------------------------------------------------------------------------

  describe "POST /staff/stuck_dnp" do
    let!(:stuck_post)       { create(:post, tag_string: "some_artist avoid_posting", locked_tags: "avoid_posting other_locked") }
    let!(:conditional_post) { create(:post, tag_string: "some_artist conditional_dnp", locked_tags: "conditional_dnp") }
    let!(:clean_post)       { create(:post, tag_string: "some_artist unrelated") }
    let(:params)            { { stuck_dnp: { query: "some_artist" } } }

    # The posts index is shared across parallel workers; keep the search off it.
    before do
      ids = [stuck_post, conditional_post, clean_post].map(&:id)
      allow(Post).to receive(:tag_match_system).and_return(Post.where(id: ids))
    end

    it "starts with the DNP tags applied and locked" do
      expect(stuck_post.reload.tag_array).to include("avoid_posting")
      expect(conditional_post.reload.tag_array).to include("conditional_dnp")
    end

    it "redirects anonymous to the login page" do
      post staff_stuck_dnp_path, params: params
      expect(response).to redirect_to(new_session_path)
      expect(stuck_post.reload.tag_array).to include("avoid_posting")
    end

    it "returns 403 for a moderator" do
      sign_in_as moderator
      expect { post staff_stuck_dnp_path, params: params }.not_to change(StaffAuditLog, :count)
      expect(response).to have_http_status(:forbidden)
      expect(stuck_post.reload.tag_array).to include("avoid_posting")
    end

    context "as an admin" do
      before { sign_in_as admin }

      it "removes the DNP tags from the matching posts" do
        post staff_stuck_dnp_path, params: params
        expect(stuck_post.reload.tag_array).not_to include("avoid_posting")
        expect(conditional_post.reload.tag_array).not_to include("conditional_dnp")
        expect(response).to redirect_to(new_staff_stuck_dnp_path)
        expect(flash[:notice]).to eq("DNP tags removed from 2 posts")
      end

      it "unlocks the DNP tags and keeps the other locked tags" do
        post staff_stuck_dnp_path, params: params
        expect(stuck_post.reload.locked_tags).to eq("other_locked")
        expect(conditional_post.reload.locked_tags).to be_blank
      end

      it "keeps the remaining tags" do
        post staff_stuck_dnp_path, params: params
        expect(stuck_post.reload.tag_array).to include("some_artist", "other_locked")
        expect(clean_post.reload.tag_array).to contain_exactly("some_artist", "unrelated")
      end

      it "does not create post versions" do
        expect { post staff_stuck_dnp_path, params: params }.not_to change(PostVersion, :count)
      end

      it "restricts the search to posts with a DNP tag" do
        post staff_stuck_dnp_path, params: params
        expect(Post).to have_received(:tag_match_system).with("some_artist ~avoid_posting ~conditional_dnp")
      end

      it "logs only the posts that changed" do
        expect { post staff_stuck_dnp_path, params: params }.to change(StaffAuditLog, :count).by(1)

        log = StaffAuditLog.last
        expect(log.action).to eq("stuck_dnp")
        expect(log.user_id).to eq(admin.id)
        expect(log[:values]["query"]).to eq("some_artist")
        expect(log[:values]["post_ids"]).to contain_exactly(stuck_post.id, conditional_post.id)
      end

      it "does nothing when the query is blank" do
        expect do
          post staff_stuck_dnp_path, params: { stuck_dnp: { query: " " } }
        end.not_to change(StaffAuditLog, :count)
        expect(Post).not_to have_received(:tag_match_system)
        expect(response).to redirect_to(new_staff_stuck_dnp_path)
        expect(flash[:notice]).to eq("No query specified")
      end

      it "returns 400 when the stuck_dnp params are missing" do
        post staff_stuck_dnp_path
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
