# frozen_string_literal: true

require "rails_helper"

#             Prefix Verb   URI Pattern                        Controller#Action
#    hide_forum_post POST   /forum_posts/:id/hide(.:format)    forum_posts#hide
#  unhide_forum_post POST   /forum_posts/:id/unhide(.:format)  forum_posts#unhide
# warning_forum_post POST   /forum_posts/:id/warning(.:format) forum_posts#warning
# search_forum_posts GET    /forum_posts/search(.:format)      forum_posts#search
#        forum_posts GET    /forum_posts(.:format)             forum_posts#index
#                    POST   /forum_posts(.:format)             forum_posts#create
#     new_forum_post GET    /forum_posts/new(.:format)         forum_posts#new
#    edit_forum_post GET    /forum_posts/:id/edit(.:format)    forum_posts#edit
#         forum_post GET    /forum_posts/:id(.:format)         forum_posts#show
#                    PATCH  /forum_posts/:id(.:format)         forum_posts#update
#                    PUT    /forum_posts/:id(.:format)         forum_posts#update
#                    DELETE /forum_posts/:id(.:format)         forum_posts#destroy
#
#             fposts GET    /fposts(.:format)                  forum_posts#index
#                    POST   /fposts(.:format)                  forum_posts#create
#          new_fpost GET    /fposts/new(.:format)              forum_posts#new
#         edit_fpost GET    /fposts/:id/edit(.:format)         forum_posts#edit
#              fpost GET    /fposts/:id(.:format)              forum_posts#show
#                    PATCH  /fposts/:id(.:format)              forum_posts#update
#                    PUT    /fposts/:id(.:format)              forum_posts#update
#                    DELETE /fposts/:id(.:format)              forum_posts#destroy
RSpec.describe ForumPostsController do
  # Enables useage in the `around` hook
  let(:user) { RSpec::Mocks.with_temporary_scope { create(:user) } }
  let(:mod) { create(:moderator_user) }
  let(:forum_topic) do
    CurrentUser.scoped(user) do
      create(:forum_topic, title: "my forum topic", original_post_attributes: { body: "alias xxx -> yyy" })
    end
  end

  let(:forum_post) { forum_topic.original_post }

  around { |example| CurrentUser.scoped(user) { example.run } }

  describe "with votes" do
    let!(:tag_alias) { CurrentUser.scoped(user) { create(:tag_alias, forum_post: forum_post, status: "pending") } }

    before do
      CurrentUser.scoped(user) { create(:forum_post_vote, forum_post: forum_post, score: 1) }
      forum_post.reload
    end

    it "to not render the vote links for the requesting user" do
      sign_in_as user
      get forum_topic_path(forum_topic)
      assert_select "li.forum-post-vote-category[data-vote='up'] button.forum-vote-up", false
      assert_select "li.forum-post-vote-category[data-vote='up'] span.forum-vote-up"
    end

    it "render the vote links" do
      sign_in_as mod
      get forum_topic_path(forum_topic)
      assert_select "li.forum-post-vote-category[data-vote='up'] button.forum-vote-up"
      assert_select "li.forum-post-vote-category[data-vote='up'] span.forum-vote-up", false
    end

    it "render existing votes" do
      sign_in_as mod
      get forum_topic_path(forum_topic)
      assert_select "ul.forum-post-votes[data-vote='up'] li"
    end

    describe "after the alias is rejected" do
      before do
        CurrentUser.scoped(mod) { tag_alias.reject! }
        sign_in_as mod
        get forum_topic_path(forum_topic)
      end

      it "hide the vote links" do
        assert_select "li.forum-post-vote-category[data-vote='up'] button.forum-vote-up", false
        assert_select "li.forum-post-vote-category[data-vote='up'] span.forum-vote-up"
      end

      it "still render existing votes" do
        assert_select "ul.forum-post-votes[data-vote='up'] li"
      end
    end
  end

  # forum_post GET    /forum_posts/:id(.:format)         forum_posts#show
  #      fpost GET    /fposts/:id(.:format)              forum_posts#show
  describe "show action" do
    it "redirects to the forum topic when the post is the original post (HTML)" do
      sign_in_as user
      get forum_post_path(forum_post)
      expect(response).to redirect_to(forum_topic_path(forum_topic))
    end

    it "renders the post directly for a reply post (HTML)" do
      reply = CurrentUser.scoped(user) { create(:forum_post, topic_id: forum_topic.id) }
      sign_in_as user
      get forum_post_path(reply)
      expect(response).to have_http_status(:success)
    end

    it "renders JSON without redirecting" do
      sign_in_as user
      get forum_post_path(forum_post, format: :json)
      expect(response).to have_http_status(:success)
    end
  end

  # forum_posts GET    /forum_posts(.:format)             forum_posts#index
  #      fposts GET    /fposts(.:format)                  forum_posts#index
  describe "index action" do
    # Renders the index path w/ JSON & HTML, and checks that the posts rendered & not rendered are
    # as expected
    # TODO: Make a generic helper for all indexes/searches
    def render_given_posts(*fps, excluded_posts: [], params: nil)
      get forum_posts_path(params: params, format: :json)
      begin
        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck("id")).to match_array(fps.pluck(:id))
        if excluded_posts.present?
          expect(response.parsed_body.pluck("id")).not_to include(*excluded_posts.pluck(:id))
        end

        get forum_posts_path(params: params)
        expect(response).to have_http_status(:success)
        fps.each { |p| assert_select "#forum-post-#{p.id}", true }
        if excluded_posts.present?
          excluded_posts.each { |p| assert_select "#forum-post-#{p.id}", false }
        end
      rescue RSpec::Expectations::ExpectationNotMetError => e
        raise RSpec::Expectations::ExpectationNotMetError, "#{e.message}\n\tParams: #{params.inspect}\n\tbody: #{response.parsed_body}", e.backtrace, cause: nil
      end
    end

    before do
      forum_post
      # Fixes error where the server sets the user to be anonymous
      make_session(user)
    end

    # TODO: Check redirects for all actions
    it "works correctly with the redirected `fpost` path" do
      get fposts_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("id")).to contain_exactly(forum_post.id)

      get fposts_path
      expect(response).to have_http_status(:success)
      assert_select "#forum-post-#{forum_post.id}"
    end

    it "list all forum posts" do # rubocop:disable RSpec/NoExpectationExample
      render_given_posts(forum_post)
    end

    describe "with posts in a hidden category" do
      let!(:forum_post2) do
        CurrentUser.scoped(mod) do
          category2 = ForumCategory.create!(name: "test", can_view: mod.level)
          forum_topic2 = create(:forum_topic, category: category2, title: "test", original_post_attributes: { body: "test" })
          forum_topic2.original_post
        end
      end

      it "only list visible posts" do # rubocop:disable RSpec/NoExpectationExample
        render_given_posts(forum_post, excluded_posts: [forum_post2])
      end
    end

    describe "with search conditions" do
      it "list all matching forum posts" do # rubocop:disable RSpec/NoExpectationExample
        render_given_posts(forum_post, params: { search: { body_matches: "xxx" } })
      end

      it "list nothing for when the search matches nothing" do # rubocop:disable RSpec/NoExpectationExample
        render_given_posts(excluded_posts: [forum_post], params: { search: { body_matches: "bababa" } })
      end

      it "list by creator id" do # rubocop:disable RSpec/NoExpectationExample
        render_given_posts(forum_post, params: { search: { creator_id: user.id } })
      end
    end
  end

  # edit_forum_post GET    /forum_posts/:id/edit(.:format)    forum_posts#edit
  #      edit_fpost GET    /fposts/:id/edit(.:format)         forum_posts#edit
  describe "edit action" do
    it "render if the editor is the creator of the topic" do
      sign_in_as user
      get edit_forum_post_path(forum_post)
      expect(response).to have_http_status(:success)
    end

    it "render if the editor is an admin" do
      sign_in_as create(:admin_user)
      get edit_forum_post_path(forum_post)
      expect(response).to have_http_status(:success)
    end

    it "fail if the editor is not the creator of the topic and is not an admin" do
      sign_in_as create(:user)
      get edit_forum_post_path(forum_post)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "new action" do
    it "render" do
      sign_in_as user
      get new_forum_post_path, params: { forum_post: { topic_id: forum_topic.id } }
      expect(response).to have_http_status(:success)
    end
  end

  describe "create action" do
    it "create a new forum post" do
      # Force the topic's creation to lock down the post count
      forum_topic

      sign_in_as user
      expect { post forum_posts_path, params: { forum_post: { body: "xaxaxa", topic_id: forum_topic.id } } }.to change(ForumPost, :count).from(1).to(2)
    end

    it "returns an error response for invalid params (empty body)" do
      forum_topic
      sign_in_as user
      post forum_posts_path(format: :json), params: { forum_post: { body: "", topic_id: forum_topic.id } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # forum_posts PATCH  /forum_posts/:id(.:format)         forum_posts#update
  #      fposts PATCH  /fposts/:id(.:format)              forum_posts#update
  describe "update action" do
    it "updates the post body when editor is the creator" do
      sign_in_as user
      put forum_post_path(forum_post), params: { forum_post: { body: "updated body" } }
      expect(response).to redirect_to(forum_topic_path(forum_topic, page: forum_post.forum_topic_page, anchor: "forum_post_#{forum_post.id}"))
      expect(forum_post.reload.body).to eq("updated body")
    end

    it "updates the post when editor is an admin" do
      sign_in_as create(:admin_user)
      put forum_post_path(forum_post), params: { forum_post: { body: "admin edit" } }
      expect(response).to redirect_to(forum_topic_path(forum_topic, page: forum_post.forum_topic_page, anchor: "forum_post_#{forum_post.id}"))
      expect(forum_post.reload.body).to eq("admin edit")
    end

    it "updates the post when editor is admin and the topic is locked" do
      forum_topic.update(is_locked: true)
      sign_in_as create(:admin_user)
      put forum_post_path(forum_post), params: { forum_post: { body: "admin edit" } }
      expect(response).to redirect_to(forum_topic_path(forum_topic, page: forum_post.forum_topic_page, anchor: "forum_post_#{forum_post.id}"))
      expect(forum_post.reload.body).to eq("admin edit")
    end

    it "returns forbidden when editor is a different member" do
      sign_in_as create(:user)
      put forum_post_path(forum_post), params: { forum_post: { body: "nope" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden when editor is the creator but the topic is locked" do
      forum_topic.update(is_locked: true)
      sign_in_as user
      put forum_post_path(forum_post), params: { forum_post: { body: "nope" } }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # forum_posts DELETE /forum_posts/:id(.:format)         forum_posts#destroy
  #      fposts DELETE /fposts/:id(.:format)              forum_posts#destroy
  describe "destroy action" do
    it "destroy the posts" do
      admin = create(:admin_user)
      sign_in_as admin
      delete forum_post_path(forum_post)
      sign_in_as admin
      get forum_post_path(forum_post)
      expect(response).to have_http_status(:not_found)
    end
  end

  #    hide_forum_post POST   /forum_posts/:id/hide(.:format)    forum_posts#hide
  describe "hide action" do
    it "allows the creator to hide their own post" do
      sign_in_as user
      post hide_forum_post_path(forum_post)
      expect(response).to redirect_to(forum_post_path(forum_post))
      expect(forum_post.reload.is_hidden?).to be(true)
    end

    it "allows a moderator to hide any post" do
      sign_in_as mod
      post hide_forum_post_path(forum_post)
      expect(forum_post.reload.is_hidden?).to be(true)
    end

    it "returns forbidden for an unrelated member" do
      sign_in_as create(:user)
      post hide_forum_post_path(forum_post)
      expect(response).to have_http_status(:forbidden)
    end
  end

  #  unhide_forum_post POST   /forum_posts/:id/unhide(.:format)  forum_posts#unhide
  describe "unhide action" do
    before do
      CurrentUser.scoped(mod) do
        forum_post.hide!
      end
    end

    it "restore the post" do
      sign_in_as mod
      post unhide_forum_post_path(forum_post)
      assert_redirected_to(forum_post_path(forum_post))
      forum_post.reload
      expect(forum_post.is_hidden?).to be(false)
    end
  end

  # warning_forum_post POST   /forum_posts/:id/warning(.:format) forum_posts#warning
  describe "warning action" do
    it "applies a warning and returns JSON with html and posts keys" do
      sign_in_as mod
      post warning_forum_post_path(forum_post), params: { record_type: "warning" }
      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include("html", "posts")
      expect(forum_post.reload.warning_type).to eq("warning")
    end

    it "removes a warning when record_type is 'unmark'" do
      CurrentUser.scoped(mod) { forum_post.user_warned!("warning", mod) }
      sign_in_as mod
      post warning_forum_post_path(forum_post), params: { record_type: "unmark" }
      expect(forum_post.reload.warning_type).to be_nil
    end

    it "returns forbidden for a regular member" do
      sign_in_as user
      post warning_forum_post_path(forum_post), params: { record_type: "warning" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
