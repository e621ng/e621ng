# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::ReownerController do
  include_context "as admin"

  let(:bd_staff)  { create(:bd_staff_user) }
  let(:admin)     { create(:admin_user) }
  let(:old_owner) { create(:user) }
  let(:new_owner) { create(:user) }

  # ---------------------------------------------------------------------------
  # GET /staff/reowner/new
  # ---------------------------------------------------------------------------

  describe "GET /staff/reowner/new" do
    it "redirects anonymous to the login page" do
      get new_staff_reowner_path
      expect(response).to redirect_to(new_session_path(url: new_staff_reowner_path))
    end

    it "returns 403 for an admin without the BD staff flag" do
      sign_in_as admin
      get new_staff_reowner_path
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for BD staff" do
      sign_in_as bd_staff
      get new_staff_reowner_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/reowner
  # ---------------------------------------------------------------------------

  describe "POST /staff/reowner" do
    let!(:posts) { create_list(:post, 2, uploader: old_owner) }
    let(:params) { { reowner: { old_owner: old_owner.name, new_owner: new_owner.name, search: "" } } }

    # The posts index is shared across parallel workers; keep the search off it.
    before { allow(Post).to receive(:tag_match).and_return(Post.where(id: posts.map(&:id))) }

    it "redirects anonymous to the login page" do
      post staff_reowner_path, params: params
      expect(response).to redirect_to(new_session_path)
      expect(posts.map { |p| p.reload.uploader_id }).to all(eq(old_owner.id))
    end

    it "returns 403 for an admin without the BD staff flag" do
      sign_in_as admin
      expect { post staff_reowner_path, params: params }.not_to change(StaffAuditLog, :count)
      expect(response).to have_http_status(:forbidden)
      expect(posts.map { |p| p.reload.uploader_id }).to all(eq(old_owner.id))
    end

    context "as BD staff" do
      before { sign_in_as bd_staff }

      it "reassigns the matching posts to the new owner" do
        post staff_reowner_path, params: params
        expect(posts.map { |p| p.reload.uploader_id }).to all(eq(new_owner.id))
        expect(response).to redirect_to(new_staff_reowner_path)
        expect(flash[:notice]).to eq("Ownership reassigned for 2 post(s)")
      end

      it "searches the old owner's posts, narrowed by the query" do
        post staff_reowner_path, params: { reowner: params[:reowner].merge(search: "some_tag") }
        expect(Post).to have_received(:tag_match).with("user:!#{old_owner.id} some_tag")
      end

      it "looks users up by !id" do
        post staff_reowner_path, params: { reowner: { old_owner: "!#{old_owner.id}", new_owner: "!#{new_owner.id}" } }
        expect(posts.map { |p| p.reload.uploader_id }).to all(eq(new_owner.id))
      end

      it "writes a staff audit log entry" do
        expect do
          post staff_reowner_path, params: { reowner: params[:reowner].merge(search: "some_tag") }
        end.to change(StaffAuditLog, :count).by(1)

        log = StaffAuditLog.last
        expect(log.action).to eq("post_owner_reassign")
        expect(log.user_id).to eq(bd_staff.id)
        expect(log[:values]).to include("old_user_id" => old_owner.id, "new_user_id" => new_owner.id, "query" => "some_tag")
        expect(log[:values]["post_ids"]).to match_array(posts.map(&:id))
      end

      it "does not create post events by default" do
        expect { post staff_reowner_path, params: params }.not_to change(PostEvent, :count)
      end

      it "creates post events when requested" do
        expect do
          post staff_reowner_path, params: { reowner: params[:reowner].merge(post_events: "1") }
        end.to change { PostEvent.where(action: :owner_changed).count }.by(2)
      end

      it "reowners versions and adjusts karma by default" do
        allow_any_instance_of(Post).to receive(:reowner!) # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(Post).to receive(:reowner!).with(new_owner, reowner_versions: true, post_events: nil, karma: true) # rubocop:disable RSpec/AnyInstance
        post staff_reowner_path, params: params
      end

      it "passes the unchecked options through" do
        allow_any_instance_of(Post).to receive(:reowner!) # rubocop:disable RSpec/AnyInstance
        expect_any_instance_of(Post).to receive(:reowner!).with(new_owner, reowner_versions: false, post_events: false, karma: false) # rubocop:disable RSpec/AnyInstance
        post staff_reowner_path, params: { reowner: params[:reowner].merge(reowner_versions: "0", post_events: "0", karma: "0") }
      end

      it "changes nothing when the old owner cannot be found" do
        expect do
          post staff_reowner_path, params: { reowner: params[:reowner].merge(old_owner: "i_am_not_a_user") }
        end.not_to change(StaffAuditLog, :count)
        expect(Post).not_to have_received(:tag_match)
        expect(response).to redirect_to(new_staff_reowner_path)
        expect(flash[:notice]).to include("failed to look up")
      end

      it "changes nothing when the new owner cannot be found" do
        post staff_reowner_path, params: { reowner: params[:reowner].merge(new_owner: "i_am_not_a_user") }
        expect(posts.map { |p| p.reload.uploader_id }).to all(eq(old_owner.id))
        expect(flash[:notice]).to include("failed to look up")
      end

      it "returns 400 when the reowner params are missing" do
        post staff_reowner_path
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
