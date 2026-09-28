# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoritesController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:other_member) { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:post_record) { create(:post) }

  # ---------------------------------------------------------------------------
  # GET /favorites — index
  # ---------------------------------------------------------------------------

  describe "GET /favorites" do
    it "returns 200 for anonymous" do
      get favorites_path(user_id: member.id)
      expect(response).to have_http_status(:ok)
    end

    it "returns a JSON array for JSON format" do
      get favorites_path(user_id: member.id, format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["posts"]).to be_an(Array)
    end

    it "redirects to posts path when tags param is a string" do
      get favorites_path(tags: "cat dog")
      expect(response).to redirect_to(posts_path(tags: "cat dog"))
    end

    it "returns 400 when tags param is not a string" do
      get favorites_path(format: :json), params: { tags: %w[cat dog] }
      expect(response).to have_http_status(:bad_request)
    end

    it "shows another user's favorites when user_id is given" do
      FavoriteManager.add!(user: other_member, post: post_record)
      sign_in_as member
      get favorites_path(user_id: other_member.id, format: :json)
      expect(response).to have_http_status(:ok)
    end

    context "when the target user has privacy mode enabled" do
      before { other_member.update_columns(bit_prefs: other_member.bit_prefs | User.flag_value_for("enable_privacy_mode")) }

      it "returns 200 but an empty post list for another member" do
        sign_in_as member
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).to be_empty
      end

      it "returns favorites to the owner themselves" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as other_member
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end

      it "returns favorites to a moderator" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as moderator
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end
    end

    context "folder-scoped browsing as the owner" do
      before { sign_in_as member }

      it "shows only root-level folders at root, and only favorites not currently filed into any folder (true folder semantics)" do
        root_folder = create(:favorite_folder, user: member, name: "Folder A")
        _nested_folder = create(:favorite_folder, user: member, name: "Nested", parent: root_folder)
        root_post = create(:post)
        FavoriteManager.add!(user: member, post: root_post)
        filed_post = create(:post)
        FavoriteManager.add!(user: member, post: filed_post)
        filed_favorite = Favorite.for_user(member.id).find_by(post_id: filed_post.id)
        create(:favorite_folder_membership, user: member, folder: root_folder, favorite: filed_favorite)

        get favorites_path
        expect(response.body).to include("Folder A")
        expect(response.body).not_to include("Nested")
        expect(response.body).to include(%(data-id="#{root_post.id}"))
        # Root means "unfiled" again - a favorite that's been filed into a folder no
        # longer appears at root once it has a membership row.
        expect(response.body).not_to include(%(data-id="#{filed_post.id}"))
      end

      it "makes a favorite reappear at root once it's moved back out of every folder" do
        folder = create(:favorite_folder, user: member)
        post = create(:post)
        FavoriteManager.add!(user: member, post: post)
        favorite = Favorite.for_user(member.id).find_by(post_id: post.id)
        create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)

        get favorites_path
        expect(response.body).not_to include(%(data-id="#{post.id}"))

        FavoriteFolderManager.move!(user: member, post: post, destination_folder_id: nil)

        get favorites_path
        expect(response.body).to include(%(data-id="#{post.id}"))
      end

      it "shows only a folder's direct child folders and direct membership rows, not descendants" do
        folder = create(:favorite_folder, user: member, name: "Folder A")
        child = create(:favorite_folder, user: member, name: "Child", parent: folder)
        grandchild = create(:favorite_folder, user: member, name: "Grandchild", parent: child)
        direct_post = create(:post)
        FavoriteManager.add!(user: member, post: direct_post)
        direct_favorite = Favorite.for_user(member.id).find_by(post_id: direct_post.id)
        create(:favorite_folder_membership, user: member, folder: folder, favorite: direct_favorite)
        descendant_post = create(:post)
        FavoriteManager.add!(user: member, post: descendant_post)
        descendant_favorite = Favorite.for_user(member.id).find_by(post_id: descendant_post.id)
        create(:favorite_folder_membership, user: member, folder: child, favorite: descendant_favorite)

        get favorites_path(folder_id: folder.id)
        expect(response.body).to include("Child")
        expect(response.body).not_to include("Grandchild")
        expect(response.body).to include(%(data-id="#{direct_post.id}"))
        expect(response.body).not_to include(%(data-id="#{descendant_post.id}"))
        _ = grandchild # referenced only to document what must not appear
      end

      it "sorts folders case-insensitively alphabetically" do
        create(:favorite_folder, user: member, name: "banana")
        create(:favorite_folder, user: member, name: "Apple")
        get favorites_path
        apple_index = response.body.index("Apple")
        banana_index = response.body.index("banana")
        expect(apple_index).to be < banana_index
      end

      it "does not show a Go Up card at root" do
        get favorites_path
        expect(response.body).not_to include("favorite-go-up-card")
      end

      it "shows a Go Up card inside a folder, targeting the parent" do
        parent = create(:favorite_folder, user: member, name: "parent")
        folder = create(:favorite_folder, user: member, name: "child", parent: parent)
        get favorites_path(folder_id: folder.id)
        expect(response.body).to include("favorite-go-up-card")
        expect(response.body).to include("data-destination-folder-id=\"#{parent.id}\"")
      end

      it "preserves folder_id across paginator links" do
        folder = create(:favorite_folder, user: member)
        14.times do
          p = create(:post)
          FavoriteManager.add!(user: member, post: p)
          favorite = Favorite.for_user(member.id).find_by(post_id: p.id)
          create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)
        end
        allow(member).to receive(:per_page).and_return(5)

        get favorites_path(folder_id: folder.id)
        expect(response.body).to match(/href="[^"]*folder_id=#{folder.id}[^"]*page=2/)
      end

      it "orders correctly across an ordinary numbered page, using an id/favorite_created_at-inverted fixture that would visibly break if id ordering ever leaked in" do
        folder = create(:favorite_folder, user: member)
        # Filed oldest-favorite_created_at last, so membership row insertion/id order runs
        # the exact opposite of the correct favorite_created_at desc display order - the one
        # fixture shape where an accidental fall-back to id ordering produces a visibly
        # wrong page instead of coincidentally matching the correct one.
        favorites = (1..4).map do |days|
          p = create(:post)
          favorite = Favorite.create!(user: member, post: p, created_at: days.days.ago)
          create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)
          favorite
        end

        get favorites_path(folder_id: folder.id, limit: 2)
        page1_positions = favorites.first(2).map { |f| response.body.index(%(data-id="#{f.post_id}")) }
        expect(page1_positions).to all(be_present)
        expect(page1_positions).to eq(page1_positions.sort)
        expect(response.body).not_to include(%(data-id="#{favorites[2].post_id}"))

        get favorites_path(folder_id: folder.id, limit: 2, page: 2)
        page2_positions = favorites[2, 2].map { |f| response.body.index(%(data-id="#{f.post_id}")) }
        expect(page2_positions).to all(be_present)
        expect(page2_positions).to eq(page2_positions.sort)
        expect(response.body).not_to include(%(data-id="#{favorites.first.post_id}"))
      end

      it "renders no Next link at all at the real Danbooru.config.max_numbered_pages ceiling - never a cursor-mode link, and never a numbered link to a page validate_numbered_page! would reject" do
        folder = create(:favorite_folder, user: member)
        allow(Danbooru.config.custom_configuration).to receive(:max_numbered_pages).and_return(2)
        3.times do |i|
          p = create(:post)
          favorite = Favorite.create!(user: member, post: p, created_at: (3 - i).days.ago)
          create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)
        end

        get favorites_path(folder_id: folder.id, limit: 1, page: 2)
        expect(response).to have_http_status(:ok)
        # PaginatorComponent's shared, unmodified `current_page >= max_numbered_pages`
        # switch would normally fire exactly here (current_page 2 == the real ceiling 2)
        # and start rendering "aXX"/"bXX" cursor links instead - proving it didn't is part
        # of the point. The other part: naively suppressing only that switch (by inflating
        # max_numbered_pages) would leave last_page/has_next? advertising page 3 - a page
        # validate_numbered_page! rejects. Neither must ever render; the "Next" control
        # must fall back to its disabled, non-link state, exactly as it does on any other
        # listing's true last page.
        expect(response.body).not_to match(/page=[ab]\d/)
        expect(response.body).not_to match(/href="[^"]*page=3/)
        expect(response.body).to match(/<span\s+class="next"\s+id="paginator-next"/)
      end

      it "still raises the standard pagination error one page past the real ceiling, exactly like any other numbered listing (not silent id-ordering)" do
        folder = create(:favorite_folder, user: member)
        allow(Danbooru.config.custom_configuration).to receive(:max_numbered_pages).and_return(2)

        get favorites_path(folder_id: folder.id, limit: 1, page: 3)
        expect(response).to have_http_status(:gone)
      end

      it "rejects a hand-crafted legacy 'bXX' cursor-mode page param outright, instead of translating it or silently falling back to page 1" do
        folder = create(:favorite_folder, user: member)
        post = create(:post)
        favorite = Favorite.create!(user: member, post: post)
        membership = create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)

        get favorites_path(folder_id: folder.id, page: "b#{membership.id}")
        expect(response).to have_http_status(:gone)
      end
    end

    context "hidden/private favorites (privacy regression)" do
      before { other_member.update_columns(bit_prefs: other_member.bit_prefs | User.flag_value_for("enable_privacy_mode")) }

      it "stays empty and folder-unaware for another member viewing HTML, even with folder_id set" do
        folder = create(:favorite_folder, user: other_member, name: "Secret")
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as member

        get favorites_path(user_id: other_member.id, folder_id: folder.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Secret")
        expect(response.body).not_to include(%(data-id="#{post_record.id}"))
      end

      it "stays empty for another member viewing JSON" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as member
        get favorites_path(user_id: other_member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).to be_empty
      end
    end

    context "when the target user is blocked" do
      let(:blocked_user) do
        user = create(:user)
        create(:ban, user: user, prevent_login: false)
        user
      end

      it "returns 200 but an empty post list for an unrelated user" do
        FavoriteManager.add!(user: blocked_user, post: post_record)
        sign_in_as member

        get favorites_path(user_id: blocked_user.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).to be_empty
      end

      it "returns 200 and the favorites list for the banned user themselves" do
        FavoriteManager.add!(user: blocked_user, post: post_record)
        sign_in_as blocked_user
        get favorites_path(user_id: blocked_user.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end

      it "returns 200 and the favorites list for a staff member" do
        FavoriteManager.add!(user: blocked_user, post: post_record)
        sign_in_as moderator
        get favorites_path(user_id: blocked_user.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["posts"]).not_to be_empty
      end
    end

    context "regression: the base Favorites query path is folder-unaware" do
      it "never queries favorite_folder_memberships for JSON" do
        FavoriteManager.add!(user: member, post: post_record)
        allow(FavoriteFolderMembership).to receive(:where).and_call_original
        get favorites_path(user_id: member.id, format: :json)
        expect(response).to have_http_status(:ok)
        expect(FavoriteFolderMembership).not_to have_received(:where)
      end

      it "never queries favorite_folder_memberships when viewing another member's favorites (HTML)" do
        FavoriteManager.add!(user: other_member, post: post_record)
        sign_in_as member
        allow(FavoriteFolderMembership).to receive(:where).and_call_original
        get favorites_path(user_id: other_member.id)
        expect(response).to have_http_status(:ok)
        expect(FavoriteFolderMembership).not_to have_received(:where)
      end

      # Owner-HTML root deliberately stopped being folder-unaware (see the "folder-scoped
      # browsing as the owner" context above) - root now means "unfiled," which requires
      # checking the sidecar table. JSON and non-owner viewing are the two paths that
      # remain, and must remain, completely flat regardless of folder membership.
      it "still shows a filed favorite in /favorites.json - JSON stays flat regardless of folder membership" do
        folder = create(:favorite_folder, user: member)
        FavoriteManager.add!(user: member, post: post_record)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)
        sign_in_as member

        get favorites_path(format: :json)
        expect(response.parsed_body["posts"].pluck("id")).to include(post_record.id)
      end

      it "still shows a filed favorite when a different member views this member's favorites page (non-owner viewing stays flat)" do
        folder = create(:favorite_folder, user: member)
        FavoriteManager.add!(user: member, post: post_record)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)
        sign_in_as other_member

        get favorites_path(user_id: member.id)
        expect(response.body).to include(%(data-id="#{post_record.id}"))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /favorites — create
  # ---------------------------------------------------------------------------

  describe "POST /favorites" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        post favorites_path, params: { post_id: post_record.id }
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before { sign_in_as member }

      it "creates a favorite and returns post_id and favorite_count" do
        expect do
          post favorites_path(format: :json), params: { post_id: post_record.id }
        end.to change(Favorite, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_id" => post_record.id, "favorite_count" => 1)
      end

      it "returns 422 when the post is already favorited" do
        FavoriteManager.add!(user: member, post: post_record)
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns 423 when favorites transfer is in progress" do
        post_record.update_columns(bit_flags: post_record.bit_flags | Post.flag_value_for("favorites_transfer_in_progress"))
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:locked)
      end

      it "returns 403 when favorites are locked down" do
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a staff member when favorites are locked down" do
      before do
        sign_in_as moderator
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
      end

      it "still allows creating a favorite" do
        post favorites_path(format: :json), params: { post_id: post_record.id }
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /favorites/:id — destroy
  # ---------------------------------------------------------------------------

  describe "DELETE /favorites/:id" do
    context "as anonymous" do
      it "redirects to the login page for HTML" do
        delete favorite_path(post_record.id)
        expect(response).to redirect_to(new_session_path)
      end

      it "returns 403 for JSON" do
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before do
        sign_in_as member
        FavoriteManager.add!(user: member, post: post_record)
      end

      it "removes the favorite and returns post_id and favorite_count" do
        expect do
          delete favorite_path(post_record.id, format: :json)
        end.to change(Favorite, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_id" => post_record.id, "favorite_count" => 0)
      end

      it "returns 423 when favorites transfer is in progress" do
        post_record.update_columns(bit_flags: post_record.bit_flags | Post.flag_value_for("favorites_transfer_in_progress"))
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:locked)
      end

      it "returns 403 when favorites are locked down" do
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a staff member when favorites are locked down" do
      before do
        sign_in_as moderator
        FavoriteManager.add!(user: moderator, post: post_record)
        allow(Security::Lockdown).to receive(:favorites_disabled?).and_return(true)
      end

      it "still allows removing a favorite" do
        delete favorite_path(post_record.id, format: :json)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /favorites/:id/move — move
  # ---------------------------------------------------------------------------

  describe "POST /favorites/:id/move" do
    context "as anonymous" do
      it "returns 403 for JSON" do
        post move_favorite_path(post_record, format: :json)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a member" do
      before do
        sign_in_as member
        FavoriteManager.add!(user: member, post: post_record)
      end

      it "returns 423 when favorites transfer is in progress" do
        folder = create(:favorite_folder, user: member)
        post_record.update_columns(bit_flags: post_record.bit_flags | Post.flag_value_for("favorites_transfer_in_progress"))
        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: folder.id }
        expect(response).to have_http_status(:locked)
        expect(FavoriteFolderMembership.where(user_id: member.id)).to be_empty
      end

      it "moves a favorite from root into a folder" do
        folder = create(:favorite_folder, user: member)
        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: folder.id }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("post_id" => post_record.id, "favorite_folder_id" => folder.id)
      end

      it "moves a favorite into a child folder" do
        parent = create(:favorite_folder, user: member, name: "parent")
        child = create(:favorite_folder, user: member, name: "child", parent: parent)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        create(:favorite_folder_membership, user: member, folder: parent, favorite: favorite)

        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: child.id }
        expect(response).to have_http_status(:ok)
        expect(FavoriteFolderMembership.find_by(favorite_id: favorite.id).folder_id).to eq(child.id)
      end

      it "moves a favorite up to the parent (Go Up)" do
        grandparent = create(:favorite_folder, user: member, name: "a")
        parent = create(:favorite_folder, user: member, name: "b", parent: grandparent)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        create(:favorite_folder_membership, user: member, folder: parent, favorite: favorite)

        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: parent.parent_id }
        expect(FavoriteFolderMembership.find_by(favorite_id: favorite.id).folder_id).to eq(grandparent.id)
      end

      it "moves a top-level folder's favorite to root (Go Up to root)" do
        folder = create(:favorite_folder, user: member)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        create(:favorite_folder_membership, user: member, folder: folder, favorite: favorite)

        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: folder.parent_id }
        expect(response.parsed_body["favorite_folder_id"]).to be_nil
        expect(FavoriteFolderMembership.find_by(favorite_id: favorite.id)).to be_nil
        expect(Favorite.exists?(favorite.id)).to be true
      end

      it "returns 422 when the destination folder belongs to another user" do
        other_folder = create(:favorite_folder, user: other_member)
        post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: other_folder.id }
        expect(response).to have_http_status(:unprocessable_content)
        favorite = Favorite.for_user(member.id).find_by(post_id: post_record.id)
        expect(FavoriteFolderMembership.find_by(favorite_id: favorite.id)).to be_nil
      end

      it "returns 422 when the post has not been favorited" do
        other_post = create(:post)
        post move_favorite_path(other_post, format: :json), params: { favorite_folder_id: nil }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not change favorite_count" do
        folder = create(:favorite_folder, user: member)
        expect { post move_favorite_path(post_record, format: :json), params: { favorite_folder_id: folder.id } }
          .not_to(change { member.reload.favorite_count })
      end
    end
  end
end
