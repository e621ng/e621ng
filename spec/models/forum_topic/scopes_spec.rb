# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           ForumTopic Scopes                                 #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  let(:member)    { create(:user) }
  let(:other)     { create(:user) }
  let(:moderator) { create(:moderator_user) }

  before do
    CurrentUser.user = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def make_topic(overrides = {})
    create(:forum_topic, **overrides)
  end

  # -------------------------------------------------------------------------
  # .for_category_id
  # -------------------------------------------------------------------------
  describe ".for_category_id" do
    it "returns only topics in the given category" do
      category_a = create(:forum_category)
      category_b = create(:forum_category)
      topic_a = make_topic(category_id: category_a.id)
      topic_b = make_topic(category_id: category_b.id)

      result = ForumTopic.for_category_id(category_a.id)
      expect(result).to include(topic_a)
      expect(result).not_to include(topic_b)
    end
  end

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    let(:public_category)     { create(:forum_category, can_view: User::Levels::ANONYMOUS) }
    let(:moderator_category)  { create(:forum_category, can_view: User::Levels::MODERATOR) }

    it "includes topics in categories the user has access to" do
      topic = make_topic(category_id: public_category.id)
      expect(ForumTopic.visible(member)).to include(topic)
    end

    it "excludes topics in categories above the user's level" do
      CurrentUser.user = moderator
      mod_topic = make_topic(category_id: moderator_category.id)
      CurrentUser.user = member

      expect(ForumTopic.visible(member)).not_to include(mod_topic)
    end

    it "excludes hidden topics from non-moderators who are not the creator" do
      topic = make_topic(category_id: public_category.id)
      topic.update_columns(is_hidden: true)

      expect(ForumTopic.visible(other)).not_to include(topic)
    end

    it "includes hidden topics created by the user themselves" do
      topic = make_topic(category_id: public_category.id)
      topic.update_columns(is_hidden: true, creator_id: member.id)

      expect(ForumTopic.visible(member)).to include(topic)
    end

    it "includes hidden topics for moderators" do
      topic = make_topic(category_id: public_category.id)
      topic.update_columns(is_hidden: true)

      expect(ForumTopic.visible(moderator)).to include(topic)
    end
  end

  # -------------------------------------------------------------------------
  # .default_order
  # -------------------------------------------------------------------------
  describe ".default_order" do
    it "returns topics newest updated_at first" do
      category = create(:forum_category)
      older = make_topic(category_id: category.id)
      newer = make_topic(category_id: category.id)
      older.update_columns(updated_at: 1.hour.ago)

      ids = ForumTopic.where(category_id: category.id).default_order.ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end

  # -------------------------------------------------------------------------
  # .sticky_first
  # -------------------------------------------------------------------------
  describe ".sticky_first" do
    it "returns stickied topics before non-stickied topics" do
      category = create(:forum_category)
      normal = make_topic(category_id: category.id)
      sticky = make_topic(category_id: category.id)
      sticky.update_columns(is_sticky: true)
      normal.update_columns(is_sticky: false)

      ids = ForumTopic.where(category_id: category.id).sticky_first.ids
      expect(ids.index(sticky.id)).to be < ids.index(normal.id)
    end

    it "orders by updated_at descending within the same sticky value" do
      category = create(:forum_category)
      older_sticky = make_topic(category_id: category.id)
      newer_sticky = make_topic(category_id: category.id)
      older_sticky.update_columns(is_sticky: true, updated_at: 2.hours.ago)
      newer_sticky.update_columns(is_sticky: true, updated_at: 1.hour.ago)

      ids = ForumTopic.where(category_id: category.id).sticky_first.ids
      expect(ids.index(newer_sticky.id)).to be < ids.index(older_sticky.id)
    end
  end
end
