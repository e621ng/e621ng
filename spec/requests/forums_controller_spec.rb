# frozen_string_literal: true

require "rails_helper"

#   forums GET /forums(.:format)     forums#index
#    forum GET /forums/:id(.:format) forums#show
RSpec.describe ForumsController do
  let(:user) { RSpec::Mocks.with_temporary_scope { create(:user) } }
  let(:category) { create(:forum_category, name: "Landing Category", can_view: 0) }

  around { |example| CurrentUser.scoped(user) { example.run } }

  def make_topic(cat, title:, sticky: false, bumped: Time.current, by: user)
    # Requests clear CurrentUser, so don't rely on the around hook here
    topic = CurrentUser.scoped(by) { create(:forum_topic, category_id: cat.id, title: title) }
    topic.update_columns(is_sticky: sticky, last_bumped_at: bumped)
    topic
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION CACHE].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  # forums GET /forums(.:format) forums#index
  describe "index action" do
    it "renders a section per visible category with its stickies and latest topics" do
      sticky = make_topic(category, title: "Pinned thread", sticky: true)
      topic = make_topic(category, title: "Fresh thread")
      sign_in_as user

      get forums_path

      expect(response).to have_http_status(:success)
      assert_select "section.forum-category[data-category-id='#{category.id}']" do
        assert_select ".forum-category-name", text: "Landing Category"
        assert_select ".forum-topic-item.pinned[data-topic-id='#{sticky.id}']"
        assert_select ".forum-topic-item:not(.pinned)[data-topic-id='#{topic.id}']"
      end
    end

    it "limits each category to its landing_topic_count" do
      category.update!(landing_topic_count: 2)
      topics = Array.new(3) { |i| make_topic(category, title: "Topic #{i}", bumped: i.hours.ago) }

      get forums_path

      assert_select "section[data-category-id='#{category.id}'] .forum-topic-item", count: 2
      assert_select ".forum-topic-item[data-topic-id='#{topics.last.id}']", count: 0
    end

    it "shows an empty state for categories without topics" do
      category

      get forums_path

      assert_select "section[data-category-id='#{category.id}'] .forum-category-empty", text: "No topics yet."
    end

    it "shows no empty state for header-only categories" do
      category.update!(landing_topic_count: 0)
      make_topic(category, title: "Not listed")

      get forums_path

      assert_select "section[data-category-id='#{category.id}'] .forum-topic-item", count: 0
      assert_select "section[data-category-id='#{category.id}'] .forum-category-empty", count: 0
    end

    it "only shows stickied topics when landing_topic_count is 0" do
      category.update!(landing_topic_count: 0)
      make_topic(category, title: "Pinned thread", sticky: true)
      make_topic(category, title: "Regular thread")

      get forums_path

      assert_select "section[data-category-id='#{category.id}'] .forum-topic-item.pinned", count: 1
      assert_select "section[data-category-id='#{category.id}'] .forum-topic-item:not(.pinned)", count: 0
    end

    it "omits categories the user cannot view" do
      staff_category = create(:forum_category, can_view: UserLevel::ADMIN)
      sign_in_as user

      get forums_path

      assert_select "section[data-category-id='#{staff_category.id}']", count: 0
    end

    it "applies the accent color" do
      category.update!(color: "#1f4f8f")

      get forums_path

      assert_select "section[data-category-id='#{category.id}'] .forum-category-header[style='--forum-accent: #1f4f8f']"
    end

    it "uses the same number of queries regardless of the number of categories" do
      sign_in_as user
      # Distinct posters, so per-row user lookups can't hide behind the query cache
      make_topic(category, title: "Sticky", sticky: true, by: create(:user))
      make_topic(category, title: "Topic", by: create(:user))
      get forums_path
      baseline = count_queries { get forums_path }

      4.times do |i|
        other = create(:forum_category, can_view: 0)
        make_topic(other, title: "Sticky #{i}", sticky: true, by: create(:user))
        make_topic(other, title: "Topic #{i}", by: create(:user))
      end
      expect(count_queries { get forums_path }).to eq(baseline)
    end
  end

  # forum GET /forums/:id(.:format) forums#show
  describe "show action" do
    it "lists the category's stickies above its topics" do
      sticky = make_topic(category, title: "Pinned thread", sticky: true)
      topic = make_topic(category, title: "Fresh thread")
      sign_in_as user

      get forum_path(category)

      expect(response).to have_http_status(:success)
      assert_select "h1.forum-category-name", text: "Landing Category"
      assert_select ".forum-topic-item.pinned[data-topic-id='#{sticky.id}']"
      assert_select ".forum-topic-item:not(.pinned)[data-topic-id='#{topic.id}']"
    end

    it "does not include topics from other categories" do
      other = make_topic(create(:forum_category), title: "Elsewhere")

      get forum_path(category)

      assert_select ".forum-topic-item[data-topic-id='#{other.id}']", count: 0
    end

    it "shows stickies on the first page only" do
      make_topic(category, title: "Pinned thread", sticky: true)
      make_topic(category, title: "Newer", bumped: 1.minute.ago)
      make_topic(category, title: "Older", bumped: 1.hour.ago)

      get forum_path(category), params: { limit: 1, page: 2 }

      assert_select ".forum-topic-item.pinned", count: 0
      assert_select ".forum-topic-item", count: 1
    end

    it "hides other users' hidden topics from members" do
      hidden = make_topic(category, title: "Hidden")
      hidden.update_columns(is_hidden: true, creator_id: create(:user).id)
      sign_in_as user

      get forum_path(category)

      assert_select ".forum-topic-item[data-topic-id='#{hidden.id}']", count: 0
    end

    it "links New topic to the category" do
      sign_in_as user

      get forum_path(category)

      assert_select "a.forum-new-topic[href=?]", new_forum_topic_path(forum_topic: { category_id: category.id })
    end

    it "returns 403 for a category above the user's level" do
      staff_category = create(:forum_category, can_view: UserLevel::ADMIN)
      sign_in_as user

      get forum_path(staff_category)

      expect(response).to have_http_status(:forbidden)
    end

    it "redirects anonymous users to login for a members-only category" do
      member_category = create(:forum_category, can_view: UserLevel::MEMBER)

      get forum_path(member_category)

      expect(response).to redirect_to(new_session_path(url: forum_path(member_category)))
    end
  end
end
