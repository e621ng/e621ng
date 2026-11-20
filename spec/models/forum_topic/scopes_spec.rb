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
    let(:public_category)     { create(:forum_category, can_view: UserLevel::ANONYMOUS) }
    let(:moderator_category)  { create(:forum_category, can_view: UserLevel::MODERATOR) }

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

  # -------------------------------------------------------------------------
  # .latest_per_category
  # -------------------------------------------------------------------------
  describe ".latest_per_category" do
    let(:busy)  { create(:forum_category, landing_topic_count: 3) }
    let(:quiet) { create(:forum_category, landing_topic_count: 1) }

    def bumped_topic(category, hours_ago, **attrs)
      topic = make_topic(category_id: category.id)
      topic.update_columns(last_bumped_at: hours_ago.hours.ago, **attrs)
      topic
    end

    it "returns each category's newest topics, up to its own landing_topic_count" do
      busy_topics = [1, 2, 3, 4].map { |h| bumped_topic(busy, h) }
      quiet_topics = [1, 2].map { |h| bumped_topic(quiet, h) }

      result = described_class.latest_per_category([busy.id, quiet.id], member).group_by(&:category_id)

      expect(result[busy.id].map(&:id)).to eq(busy_topics.first(3).map(&:id))
      expect(result[quiet.id].map(&:id)).to eq([quiet_topics.first.id])
    end

    it "excludes stickies" do
      sticky = bumped_topic(busy, 1, is_sticky: true)
      normal = bumped_topic(busy, 2)

      expect(described_class.latest_per_category([busy.id], member)).to eq([normal])
      expect(described_class.latest_per_category([busy.id], member)).not_to include(sticky)
    end

    it "skips categories with a landing_topic_count of 0" do
      busy.update_columns(landing_topic_count: 0)
      bumped_topic(busy, 1)

      expect(described_class.latest_per_category([busy.id], member)).to be_empty
    end

    it "only covers the given categories" do
      bumped_topic(busy, 1)
      topic = bumped_topic(quiet, 1)

      expect(described_class.latest_per_category([quiet.id], member)).to eq([topic])
    end

    it "returns nothing for no categories" do
      expect(described_class.latest_per_category([], member)).to be_empty
    end

    it "orders by category order, then newest first" do
      busy.update_columns(cat_order: 2)
      quiet.update_columns(cat_order: 1)
      busy_topic = bumped_topic(busy, 1)
      quiet_topic = bumped_topic(quiet, 2)

      expect(described_class.latest_per_category([busy.id, quiet.id], member)).to eq([quiet_topic, busy_topic])
    end

    describe "hidden topics" do
      let!(:hidden) { bumped_topic(busy, 1, is_hidden: true, creator_id: other.id) }

      it "are excluded for other members, matching .visible" do
        expect(described_class.latest_per_category([busy.id], member)).not_to include(hidden)
        expect(described_class.visible(member)).not_to include(hidden)
      end

      it "are included for their creator, matching .visible" do
        expect(described_class.latest_per_category([busy.id], other)).to include(hidden)
        expect(described_class.visible(other)).to include(hidden)
      end

      it "are included for staff, matching .visible" do
        expect(described_class.latest_per_category([busy.id], moderator)).to include(hidden)
        expect(described_class.visible(moderator)).to include(hidden)
      end
    end
  end
end
