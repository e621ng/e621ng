# frozen_string_literal: true

require "rails_helper"

#              forum_topics GET    /forum_topics(.:format)                          forum_topics#index
#                           POST   /forum_topics(.:format)                          forum_topics#create
#           new_forum_topic GET    /forum_topics/new(.:format)                      forum_topics#new
#          edit_forum_topic GET    /forum_topics/:id/edit(.:format)                 forum_topics#edit
#               forum_topic GET    /forum_topics/:id(.:format)                      forum_topics#show
#                           PATCH  /forum_topics/:id(.:format)                      forum_topics#update
#                           DELETE /forum_topics/:id(.:format)                      forum_topics#destroy
#          hide_forum_topic POST   /forum_topics/:id/hide(.:format)                 forum_topics#hide
#        unhide_forum_topic POST   /forum_topics/:id/unhide(.:format)               forum_topics#unhide
#     subscribe_forum_topic POST   /forum_topics/:id/subscribe(.:format)            forum_topics#subscribe
#   unsubscribe_forum_topic POST   /forum_topics/:id/unsubscribe(.:format)          forum_topics#unsubscribe
# mark_all_as_read_forum_topics POST /forum_topics/mark_all_as_read(.:format)       forum_topics#mark_all_as_read
RSpec.describe ForumTopicsController do
  let(:user) { RSpec::Mocks.with_temporary_scope { create(:user) } }
  let(:mod) { create(:moderator_user) }
  let(:admin) { create(:admin_user) }
  let(:forum_topic) do
    CurrentUser.scoped(user) { create(:forum_topic, title: "my forum topic") }
  end

  around { |example| CurrentUser.scoped(user) { example.run } }

  # forum_topics GET /forum_topics(.:format) forum_topics#index
  describe "index action" do
    before { forum_topic }

    it "lists all visible topics (HTML)" do
      get_auth forum_topics_path, user
      expect(response).to have_http_status(:success)
      assert_select "a.forum-post-link", text: forum_topic.title
    end

    it "lists all visible topics (JSON)" do
      get_auth forum_topics_path(format: :json), user
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("id")).to include(forum_topic.id)
    end

    it "excludes topics in categories above the user's view level" do
      hidden_category = create(:forum_category, can_view: User::Levels::MODERATOR)
      hidden_topic = CurrentUser.scoped(mod) { create(:forum_topic, category: hidden_category) }

      get_auth forum_topics_path(format: :json), user
      expect(response.parsed_body.pluck("id")).not_to include(hidden_topic.id)
    end

    it "filters by title_matches (wildcard)" do
      other_topic = CurrentUser.scoped(user) { create(:forum_topic, title: "completely different") }

      get_auth forum_topics_path(format: :json), user, params: { search: { title_matches: "my forum*" } }
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(forum_topic.id)
      expect(ids).not_to include(other_topic.id)
    end

    it "filters by exact title via search[title]" do
      other_topic = CurrentUser.scoped(user) { create(:forum_topic, title: "something else") }

      get_auth forum_topics_path(format: :json), user, params: { search: { title: "my forum topic" } }
      ids = response.parsed_body.pluck("id")
      expect(ids).to include(forum_topic.id)
      expect(ids).not_to include(other_topic.id)
    end

    it "promotes top-level title_matches param into search[title_matches]" do
      get_auth forum_topics_path(format: :json), user, params: { title_matches: "my forum*" }
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck("id")).to include(forum_topic.id)
    end

    it "applies sticky-first ordering on HTML requests by default" do
      sticky_topic = CurrentUser.scoped(mod) { create(:forum_topic, title: "sticky topic title") }
      CurrentUser.scoped(user) { create(:forum_topic, title: "normal topic title") }
      CurrentUser.scoped(mod) { sticky_topic.update_columns(is_sticky: true) }

      get_auth forum_topics_path, user
      expect(response).to have_http_status(:success)
      sticky_pos = response.body.index("sticky topic title")
      normal_pos = response.body.index("normal topic title")
      expect(sticky_pos).to be < normal_pos
    end
  end

  # forum_topic GET /forum_topics/:id(.:format) forum_topics#show
  describe "show action" do
    it "renders HTML successfully and marks the topic as read" do
      # mark_as_read! may prune the visit immediately if no unread topics remain,
      # so we verify the user's last_forum_read_at is updated instead of the count.
      user.update_columns(last_forum_read_at: 1.hour.ago)
      get_auth forum_topic_path(forum_topic), user
      expect(response).to have_http_status(:success)
      expect(user.reload.last_forum_read_at).to be > 1.minute.ago
    end

    it "renders JSON successfully without creating a visit" do
      expect do
        get_auth forum_topic_path(forum_topic, format: :json), user
      end.not_to change(ForumTopicVisit, :count)
      expect(response).to have_http_status(:success)
    end

    it "returns 403 for a hidden topic when the user is not a moderator or creator" do
      forum_topic.update_columns(is_hidden: true)
      other_user = create(:user)
      get_auth forum_topic_path(forum_topic), other_user
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a moderator to view a hidden topic" do
      forum_topic.update_columns(is_hidden: true)
      get_auth forum_topic_path(forum_topic), mod
      expect(response).to have_http_status(:success)
    end
  end

  # new_forum_topic GET /forum_topics/new(.:format) forum_topics#new
  describe "new action" do
    it "renders for a logged-in member" do
      get_auth new_forum_topic_path, user
      expect(response).to have_http_status(:success)
    end

    it "redirects anonymous users to login" do
      get new_forum_topic_path
      expect(response).to redirect_to(new_session_path(url: new_forum_topic_path))
    end
  end

  # forum_topics POST /forum_topics(.:format) forum_topics#create
  describe "create action" do
    let(:category) { create(:forum_category) }
    let(:valid_params) do
      { forum_topic: { title: "new topic", category_id: category.id, original_post_attributes: { body: "hello world" } } }
    end

    it "creates a forum topic with valid params" do
      expect do
        post_auth forum_topics_path, user, params: valid_params
      end.to change(ForumTopic, :count).by(1)
    end

    it "returns 422 for invalid params (empty title) via JSON" do
      post_auth forum_topics_path(format: :json), user,
                params: { forum_topic: { title: "", category_id: category.id, original_post_attributes: { body: "body" } } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "redirects anonymous users to login" do
      post forum_topics_path, params: valid_params
      expect(response).to redirect_to(new_session_path)
    end
  end

  # edit_forum_topic GET /forum_topics/:id/edit(.:format) forum_topics#edit
  describe "edit action" do
    it "renders for the creator" do
      get_auth edit_forum_topic_path(forum_topic), user
      expect(response).to have_http_status(:success)
    end

    it "renders for a moderator (non-creator)" do
      get_auth edit_forum_topic_path(forum_topic), mod
      expect(response).to have_http_status(:success)
    end

    it "returns 403 for an unrelated member" do
      get_auth edit_forum_topic_path(forum_topic), create(:user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # forum_topic PATCH /forum_topics/:id(.:format) forum_topics#update
  describe "update action" do
    it "updates the title when the editor is the creator" do
      put_auth forum_topic_path(forum_topic), user, params: { forum_topic: { title: "updated title" } }
      expect(forum_topic.reload.title).to eq("updated title")
    end

    it "updates the title when the editor is a moderator" do
      put_auth forum_topic_path(forum_topic), mod, params: { forum_topic: { title: "mod updated" } }
      expect(forum_topic.reload.title).to eq("mod updated")
    end

    it "returns 403 for an unrelated member" do
      put_auth forum_topic_path(forum_topic), create(:user), params: { forum_topic: { title: "nope" } }
      expect(response).to have_http_status(:forbidden)
    end

    it "allows a moderator to set is_sticky" do
      put_auth forum_topic_path(forum_topic), mod, params: { forum_topic: { is_sticky: true } }
      expect(forum_topic.reload.is_sticky).to be(true)
    end

    it "ignores is_sticky from a non-moderator (unpermitted param)" do
      put_auth forum_topic_path(forum_topic), user, params: { forum_topic: { title: "same", is_sticky: true } }
      expect(forum_topic.reload.is_sticky).to be(false)
    end
  end

  # forum_topic DELETE /forum_topics/:id(.:format) forum_topics#destroy
  describe "destroy action" do
    it "allows an admin to destroy the topic" do
      forum_topic
      expect do
        delete_auth forum_topic_path(forum_topic), admin
      end.to change(ForumTopic, :count).by(-1)
      expect(response).to redirect_to(forum_topics_path)
    end

    it "sets a flash notice on successful destruction" do
      delete_auth forum_topic_path(forum_topic), admin
      expect(flash[:notice]).to eq("Topic destroyed")
    end

    it "returns 403 for a moderator (admin_only)" do
      delete_auth forum_topic_path(forum_topic), mod
      expect(response).to have_http_status(:forbidden)
    end
  end

  # hide_forum_topic POST /forum_topics/:id/hide(.:format) forum_topics#hide
  describe "hide action" do
    it "allows the creator to hide their own topic" do
      post_auth hide_forum_topic_path(forum_topic), user
      expect(forum_topic.reload.is_hidden).to be(true)
    end

    it "allows a moderator to hide any topic" do
      post_auth hide_forum_topic_path(forum_topic), mod
      expect(forum_topic.reload.is_hidden).to be(true)
    end

    it "returns 403 for an unrelated member" do
      post_auth hide_forum_topic_path(forum_topic), create(:user)
      expect(response).to have_http_status(:forbidden)
    end

    it "sets a flash notice" do
      post_auth hide_forum_topic_path(forum_topic), user
      expect(flash[:notice]).to eq("Topic hidden")
    end
  end

  # unhide_forum_topic POST /forum_topics/:id/unhide(.:format) forum_topics#unhide
  describe "unhide action" do
    before { forum_topic.update_columns(is_hidden: true) }

    it "allows a moderator to unhide a topic" do
      post_auth unhide_forum_topic_path(forum_topic), mod
      expect(forum_topic.reload.is_hidden).to be(false)
    end

    it "returns 403 for a regular member (moderator_only)" do
      post_auth unhide_forum_topic_path(forum_topic), user
      expect(response).to have_http_status(:forbidden)
    end

    it "sets a flash notice" do
      post_auth unhide_forum_topic_path(forum_topic), mod
      expect(flash[:notice]).to eq("Topic unhidden")
    end
  end

  # mark_all_as_read_forum_topics POST /forum_topics/mark_all_as_read(.:format) forum_topics#mark_all_as_read
  describe "mark_all_as_read action" do
    it "redirects to the index with a notice" do
      post_auth mark_all_as_read_forum_topics_path, user
      expect(response).to redirect_to(forum_topics_path)
      expect(flash[:notice]).to eq("All topics marked as read")
    end

    it "updates the user's last_forum_read_at" do
      old_time = 1.hour.ago
      user.update_columns(last_forum_read_at: old_time)
      post_auth mark_all_as_read_forum_topics_path, user
      expect(user.reload.last_forum_read_at).to be > old_time
    end

    it "redirects anonymous users to login" do
      post mark_all_as_read_forum_topics_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  # subscribe_forum_topic POST /forum_topics/:id/subscribe(.:format) forum_topics#subscribe
  describe "subscribe action" do
    it "creates a ForumSubscription" do
      expect do
        post_auth subscribe_forum_topic_path(forum_topic), user
      end.to change(ForumSubscription, :count).by(1)
    end

    it "is idempotent: does not create a duplicate subscription" do
      create(:forum_subscription, forum_topic: forum_topic, user: user)
      expect do
        post_auth subscribe_forum_topic_path(forum_topic), user
      end.not_to change(ForumSubscription, :count)
    end
  end

  # unsubscribe_forum_topic POST /forum_topics/:id/unsubscribe(.:format) forum_topics#unsubscribe
  describe "unsubscribe action" do
    it "destroys an existing subscription" do
      create(:forum_subscription, forum_topic: forum_topic, user: user)
      expect do
        post_auth unsubscribe_forum_topic_path(forum_topic), user
      end.to change(ForumSubscription, :count).by(-1)
    end

    it "is a no-op when no subscription exists" do
      expect do
        post_auth unsubscribe_forum_topic_path(forum_topic), user
      end.not_to change(ForumSubscription, :count)
    end
  end
end
