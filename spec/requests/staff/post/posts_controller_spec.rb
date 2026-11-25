# frozen_string_literal: true

require "rails_helper"

RSpec.describe Staff::Post::PostsController do
  include_context "as admin"

  let(:approver)         { create(:approver_user) }
  let(:janitor)          { create(:janitor_user) }
  let(:janitor_approver) { create(:janitor_user, can_approve_posts: true) }
  let(:admin)            { create(:admin_user, can_approve_posts: true) }
  let(:member)           { create(:user) }
  let(:post_record)      { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /staff/post/posts/:id/confirm_delete
  # ---------------------------------------------------------------------------

  describe "GET /staff/post/posts/:id/confirm_delete" do
    it "redirects anonymous to the login page" do
      get confirm_delete_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: confirm_delete_staff_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get confirm_delete_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an approver" do
      sign_in_as approver
      get confirm_delete_staff_post_post_path(post_record)
      expect(response).to have_http_status(:ok)
    end

    context "with a DNP entry" do
      def dnp_input_value(details)
        dnp = create(:avoid_posting, details: details)
        allow_any_instance_of(Post).to receive(:avoid_posting_tags).and_return([dnp]) # rubocop:disable RSpec/AnyInstance
        allow(Danbooru.config.custom_configuration).to receive(:deletion_reasons).and_return(["Conditional DNP (%DNP_ID%)"])

        sign_in_as approver
        get confirm_delete_staff_post_post_path(post_record)
        expect(response).to have_http_status(:ok)
        response.parsed_body.at_css("#delreason-prebuilt input[type=text]")&.[]("value")
      end

      it "escapes the details into the reason input" do
        details = "'><b>INJECTED</b><input value='"
        expect(dnp_input_value(details)).to eq(details)
        expect(response.body).not_to include("<b>INJECTED</b>")
      end

      it "does not expand gsub backreferences in the details" do
        expect(dnp_input_value('a\\0b\\&c')).to eq('a\\0b\\&c')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/delete
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/delete" do
    it "redirects anonymous to the login page" do
      post delete_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post delete_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an approver" do
      before { sign_in_as approver }

      it "soft-deletes the post and redirects when commit=Delete with a reason" do
        post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "rule violation" }
        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.is_deleted?).to be true
      end

      it "redirects back to confirm_delete with a flash when reason is blank" do
        post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "" }
        expect(response).to redirect_to(confirm_delete_staff_post_post_path(post_record))
        expect(flash[:notice]).to be_present
      end

      it "does not delete and redirects when commit is not Delete" do
        post delete_staff_post_post_path(post_record), params: { commit: "Cancel" }
        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.is_deleted?).to be false
      end

      it "passes the search query back to confirm_delete when reason is blank" do
        post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "", q: "some_tag" }
        expect(response).to redirect_to(confirm_delete_staff_post_post_path(post_record, q: "some_tag"))
        expect(post_record.reload.is_deleted?).to be false
      end

      context "when deleting from a flag without giving a reason" do
        it "uses the flag's reason" do
          flag = create(:post_flag, post: post_record)
          post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "", from_flag: "1" }
          expect(response).to redirect_to(post_path(post_record))
          expect(post_record.reload.is_deleted?).to be true
          expect(post_record.flags.where(is_deletion: true).last.reason).to eq(flag.reason)
        end

        it "fills %REASON% in the dmail with the flag's reason" do
          flag = create(:post_flag, post: post_record)
          post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "", from_flag: "1", dmail: "Deleted: %REASON%" }
          expect(Dmail.where(to_id: post_record.uploader_id).last.body).to eq("Deleted: #{flag.reason}")
        end

        it "is rejected when from_flag is not set" do
          create(:post_flag, post: post_record)
          post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "" }
          expect(response).to redirect_to(confirm_delete_staff_post_post_path(post_record))
          expect(flash[:notice]).to eq("You must provide a reason for the deletion")
          expect(post_record.reload.is_deleted?).to be false
        end

        it "is rejected when the flag reason needs an explicit staff reason" do
          create(:needs_staff_reason_post_flag, post: post_record)
          post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "", from_flag: "1" }
          expect(response).to redirect_to(confirm_delete_staff_post_post_path(post_record))
          expect(flash[:notice]).to eq("You must explicitly provide a deletion reason for this flag")
          expect(post_record.reload.is_deleted?).to be false
        end
      end

      context "with a dmail" do
        let(:params) { { commit: "Delete", reason: "rule violation", dmail: "Post #%POST_ID% was deleted: %REASON%" } }

        it "notifies the uploader with the placeholders filled in" do
          expect { post delete_staff_post_post_path(post_record), params: params }.to change { Dmail.where(to_id: post_record.uploader_id).count }.by(1)
          expect(Dmail.where(to_id: post_record.uploader_id).last).to have_attributes(
            from_id: User.system.id,
            title: "Post ##{post_record.id} has been deleted",
            body: "Post ##{post_record.id} was deleted: rule violation",
          )
        end

        it "uses the given dmail title" do
          post delete_staff_post_post_path(post_record), params: params.merge(dmail_title: "About post #%POST_ID%")
          expect(Dmail.where(to_id: post_record.uploader_id).last.title).to eq("About post ##{post_record.id}")
        end

        it "sends nothing when the deletion is cancelled" do
          expect { post delete_staff_post_post_path(post_record), params: params.merge(commit: "Cancel") }.not_to change(Dmail, :count)
        end

        it "sends nothing without a dmail body" do
          expect { post delete_staff_post_post_path(post_record), params: params.merge(dmail: "") }.not_to change(Dmail, :count)
        end
      end

      context "when the post has a parent" do
        let(:parent)      { create(:post, source: "https://parent.example/a") }
        let(:post_record) { create(:post, parent_id: parent.id, source: "https://child.example/b", tag_string: "child_only_tag shared_tag") }
        let(:params)      { { commit: "Delete", reason: "inferior version" } }

        it "leaves the parent alone by default" do
          expect { post delete_staff_post_post_path(post_record), params: params }.not_to(change { parent.reload.attributes.slice("source", "tag_string") })
          expect(TransferFavoritesJob).not_to have_enqueued_sidekiq_job
        end

        it "copies sources to the parent when requested" do
          post delete_staff_post_post_path(post_record), params: params.merge(copy_sources: "1")
          expect(parent.reload.source).to include("https://parent.example/a", "https://child.example/b")
        end

        it "copies tags to the parent when requested" do
          post delete_staff_post_post_path(post_record), params: params.merge(copy_tags: "1")
          expect(parent.reload.tag_array).to include("child_only_tag", "shared_tag")
        end

        it "queues a favorites transfer when requested" do
          post delete_staff_post_post_path(post_record), params: params.merge(move_favorites: "1")
          expect(TransferFavoritesJob).to have_enqueued_sidekiq_job(post_record.id, approver.id)
        end

        it "moves the post's sets to the parent when moving favorites" do
          set = create(:post_set, transfer_on_delete: true)
          set.add!(post_record)
          set.save!
          post delete_staff_post_post_path(post_record), params: params.merge(move_favorites: "1")
          expect(set.reload.post_ids).to eq([parent.id])
        end
      end

      it "ignores the transfer options for a post without a parent" do
        post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "rule violation", copy_tags: "1", copy_sources: "1", move_favorites: "1" }
        expect(post_record.reload.is_deleted?).to be true
        expect(TransferFavoritesJob).not_to have_enqueued_sidekiq_job
      end

      context "when the post is already deleted" do
        let(:post_record) { create(:deleted_post) }

        it "shows a flash notice and redirects for HTML" do
          post delete_staff_post_post_path(post_record), params: { commit: "Delete", reason: "rule violation" }
          expect(response).to redirect_to(post_path(post_record))
          expect(flash[:notice]).to match(/already deleted/)
        end

        it "returns 409 for JSON" do
          post delete_staff_post_post_path(post_record, format: :json), params: { commit: "Delete", reason: "rule violation" }
          expect(response).to have_http_status(:conflict)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/undelete
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/undelete" do
    let(:deleted_post) { create(:deleted_post) }

    it "redirects anonymous to the login page" do
      post undelete_staff_post_post_path(deleted_post)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post undelete_staff_post_post_path(deleted_post)
      expect(response).to have_http_status(:forbidden)
    end

    it "undeletes the post and redirects for an approver" do
      sign_in_as approver
      post undelete_staff_post_post_path(deleted_post)
      expect(response).to redirect_to(post_path(deleted_post))
      expect(deleted_post.reload.is_deleted?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/post/posts/:id/confirm_move_favorites
  # ---------------------------------------------------------------------------

  describe "GET /staff/post/posts/:id/confirm_move_favorites" do
    it "redirects anonymous to the login page" do
      get confirm_move_favorites_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: confirm_move_favorites_staff_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get confirm_move_favorites_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 for an approver" do
      sign_in_as approver
      get confirm_move_favorites_staff_post_post_path(post_record)
      expect(response).to have_http_status(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/move_favorites
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/move_favorites" do
    it "redirects anonymous to the login page" do
      post move_favorites_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post move_favorites_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    context "as an approver" do
      before { sign_in_as approver }

      it "redirects to the post when commit is not Submit" do
        post move_favorites_staff_post_post_path(post_record)
        expect(response).to redirect_to(post_path(post_record))
      end

      it "moves favorites and redirects when commit=Submit" do
        parent       = create(:post)
        post_record  = create(:post, parent: parent)
        post move_favorites_staff_post_post_path(post_record), params: { commit: "Submit" }
        expect(response).to redirect_to(post_path(post_record))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/expunge
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/expunge" do
    it "redirects anonymous to the login page" do
      post expunge_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post expunge_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without admin level" do
      sign_in_as approver
      post expunge_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "expunges the post and redirects for an admin" do
      target = post_record
      allow_any_instance_of(Post).to receive(:expunge!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as admin
      post expunge_staff_post_post_path(target)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/regenerate_thumbnails
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/regenerate_thumbnails" do
    it "redirects anonymous to the login page" do
      post regenerate_thumbnails_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post regenerate_thumbnails_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      post regenerate_thumbnails_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "regenerates thumbnails and redirects for a janitor" do
      allow_any_instance_of(Post).to receive(:regenerate_image_samples!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor
      post regenerate_thumbnails_staff_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/regenerate_videos
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/regenerate_videos" do
    it "redirects anonymous to the login page" do
      post regenerate_videos_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post regenerate_videos_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      post regenerate_videos_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "regenerates video samples and redirects for a janitor" do
      allow_any_instance_of(Post).to receive(:regenerate_video_samples!).and_return(true) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor
      post regenerate_videos_staff_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end

    it "returns 403 for a deleted post" do
      deleted = create(:deleted_post)
      sign_in_as janitor
      post regenerate_videos_staff_post_post_path(deleted)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/post/posts/:id/ai_check
  # ---------------------------------------------------------------------------

  describe "GET /staff/post/posts/:id/ai_check" do
    it "redirects anonymous to the login page" do
      get ai_check_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: ai_check_staff_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get ai_check_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      get ai_check_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without approver rights" do
      sign_in_as janitor
      get ai_check_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "runs the AI check and redirects for a janitor with approver rights" do
      allow_any_instance_of(Post).to receive(:check_for_ai_content).and_return({ score: 0, reason: "" }) # rubocop:disable RSpec/AnyInstance
      sign_in_as janitor_approver
      get ai_check_staff_post_post_path(post_record)
      expect(response).to have_http_status(:redirect)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /staff/post/posts/:id/previous_owners
  # ---------------------------------------------------------------------------

  describe "GET /staff/post/posts/:id/previous_owners" do
    it "redirects anonymous to the login page" do
      get previous_owners_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path(url: previous_owners_staff_post_post_path(post_record)))
    end

    it "returns 403 for a member" do
      sign_in_as member
      get previous_owners_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 200 and the JSON array for an approver" do
      sign_in_as approver
      user1 = create(:user)
      allow_any_instance_of(Post).to receive(:previous_version_uploaders).and_return([user1]) # rubocop:disable RSpec/AnyInstance
      get previous_owners_staff_post_post_path(post_record, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.first["id"]).to eq(user1.id)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /staff/post/posts/:id/reowner
  # ---------------------------------------------------------------------------

  describe "POST /staff/post/posts/:id/reowner" do
    let(:new_owner) { create(:user) }

    it "redirects anonymous to the login page" do
      post reowner_staff_post_post_path(post_record)
      expect(response).to redirect_to(new_session_path)
    end

    it "returns 403 for a member" do
      sign_in_as member
      post reowner_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for an approver without janitor level" do
      sign_in_as approver
      post reowner_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 for a janitor without approver rights" do
      sign_in_as janitor
      post reowner_staff_post_post_path(post_record)
      expect(response).to have_http_status(:forbidden)
    end

    context "as a janitor with approver rights" do
      before { sign_in_as janitor_approver }

      it "sets a flash alert if the new owner could not be found" do
        post reowner_staff_post_post_path(post_record), params: { reowner: { new_owner: "I_AM_NOT_A_USER" } }
        expect(flash[:alert]).to match(/New owner could not be found/)
      end

      it "returns 422 with the message over JSON if the new owner could not be found" do
        post reowner_staff_post_post_path(post_record, format: :json), params: { reowner: { new_owner: "I_AM_NOT_A_USER" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["message"]).to match(/New owner could not be found/)
      end

      it "calls reowner! and redirects if the user is found" do
        allow_any_instance_of(Post).to receive(:reowner!).with(new_owner, post_events: true, reowner_versions: false, karma: true).and_return(9999) # rubocop:disable RSpec/AnyInstance
        expect do
          post reowner_staff_post_post_path(post_record), params: { reowner: { new_owner: new_owner.name } }
        end.not_to change(StaffAuditLog, :count)
        expect(response).to redirect_to(post_path(post_record))
      end

      it "creates a staff audit log entry when disabling reowner post events" do
        allow_any_instance_of(Post).to receive(:reowner!).with(new_owner, post_events: false, reowner_versions: false, karma: true).and_return(9999) # rubocop:disable RSpec/AnyInstance
        expect do
          post reowner_staff_post_post_path(post_record), params: { reowner: { new_owner: new_owner.name, post_events: false } }
        end.to change(StaffAuditLog, :count).by(1)
        expect(response).to redirect_to(post_path(post_record))
        expect(StaffAuditLog.last.action).to eq("post_owner_reassign")
        expect(StaffAuditLog.last[:values]).to include("old_user_id" => 9999, "new_user_id" => new_owner.id, "query" => "", "post_ids" => [post_record.id])
      end

      it "passes karma: false through to reowner!" do
        allow_any_instance_of(Post).to receive(:reowner!).with(new_owner, post_events: true, reowner_versions: false, karma: false).and_return(9999) # rubocop:disable RSpec/AnyInstance
        post reowner_staff_post_post_path(post_record), params: { reowner: { new_owner: new_owner.name, karma: "false" } }
        expect(response).to redirect_to(post_path(post_record))
      end
    end
  end
end
