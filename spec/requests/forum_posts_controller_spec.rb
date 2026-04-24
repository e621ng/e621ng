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
# TODO: Test permissions
# TODO: Test `warning` action
# TODO: Test `update` action
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
      get_auth forum_topic_path(forum_topic), user
      assert_select "li.forum-post-vote-category[data-vote='up'] button.forum-vote-up", false
      assert_select "li.forum-post-vote-category[data-vote='up'] span.forum-vote-up"
    end

    it "render the vote links" do
      get_auth forum_topic_path(forum_topic), mod
      assert_select "li.forum-post-vote-category[data-vote='up'] button.forum-vote-up"
      assert_select "li.forum-post-vote-category[data-vote='up'] span.forum-vote-up", false
    end

    it "render existing votes" do
      get_auth forum_topic_path(forum_topic), mod
      assert_select "ul.forum-post-votes[data-vote='up'] li"
    end

    describe "after the alias is rejected" do
      before do
        CurrentUser.scoped(mod) { tag_alias.reject! }
        get_auth forum_topic_path(forum_topic), mod
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
      get_auth edit_forum_post_path(forum_post), user
      expect(response).to have_http_status(:success)
    end

    it "render if the editor is an admin" do
      get_auth edit_forum_post_path(forum_post), create(:admin_user)
      expect(response).to have_http_status(:success)
    end

    it "fail if the editor is not the creator of the topic and is not an admin" do
      get_auth edit_forum_post_path(forum_post), create(:user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "new action" do
    it "render" do
      get_auth new_forum_post_path, user, params: { forum_post: { topic_id: forum_topic.id } }
      expect(response).to have_http_status(:success)
    end
  end

  describe "create action" do
    it "create a new forum post" do
      # Force the topic's creation to lock down the post count
      forum_topic

      expect { post_auth forum_posts_path, user, params: { forum_post: { body: "xaxaxa", topic_id: forum_topic.id } } }.to change(ForumPost, :count).from(1).to(2)
    end
  end

  # forum_posts DELETE /forum_posts/:id(.:format)         forum_posts#destroy
  #      fposts DELETE /fposts/:id(.:format)              forum_posts#destroy
  describe "destroy action" do
    it "destroy the posts" do
      admin = create(:admin_user)
      delete_auth forum_post_path(forum_post), admin
      get_auth forum_post_path(forum_post), admin
      expect(response).to have_http_status(:not_found)
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
      post_auth unhide_forum_post_path(forum_post), mod
      assert_redirected_to(forum_post_path(forum_post))
      forum_post.reload
      expect(forum_post.is_hidden?).to be(false)
    end
  end
end
