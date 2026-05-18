# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ForumPost Validations                               #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  include_context "as member"

  let(:topic) { create(:forum_topic) }

  def make_post(overrides = {})
    create(:forum_post, topic_id: topic.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # body
  # -------------------------------------------------------------------------
  describe "body" do
    it "is invalid when blank" do
      record = build(:forum_post, topic_id: topic.id, body: "")
      expect(record).not_to be_valid
      expect(record.errors[:body]).to be_present
    end

    it "is invalid when longer than the configured maximum" do
      record = build(:forum_post, topic_id: topic.id, body: "a" * (Danbooru.config.forum_post_max_size + 1))
      expect(record).not_to be_valid
      expect(record.errors[:body]).to be_present
    end

    it "is valid at exactly the maximum length" do
      record = build(:forum_post, topic_id: topic.id, body: "a" * Danbooru.config.forum_post_max_size)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # creator_id
  # -------------------------------------------------------------------------
  describe "creator_id" do
    it "is invalid when nil" do
      record = make_post
      record.creator_id = nil
      expect(record).not_to be_valid
      expect(record.errors[:creator_id]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # topic is valid
  # -------------------------------------------------------------------------
  describe "topic" do
    it "is invalid when topic_id references a non-existent record" do
      record = build(:forum_post, topic_id: -1)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("Topic ID is invalid")
    end

    it "is invalid on create when the topic's category requires a higher view level" do
      restricted = create(:forum_category, can_view: User::Levels::MODERATOR)
      restricted_topic = CurrentUser.scoped(create(:moderator_user)) { create(:forum_topic, category_id: restricted.id) }
      record = build(:forum_post, topic_id: restricted_topic.id)
      expect(record).not_to be_valid
      expect(record.errors[:topic]).to include("is restricted")
    end

    it "is invalid on create when the topic's category does not allow replies at the user's level" do
      restricted = create(:forum_category, can_reply: User::Levels::MODERATOR)
      restricted_topic = CurrentUser.scoped(create(:moderator_user)) { create(:forum_topic, category_id: restricted.id) }
      record = build(:forum_post, topic_id: restricted_topic.id)
      expect(record).not_to be_valid
      expect(record.errors[:topic]).to include("does not allow replies")
    end
  end

  # -------------------------------------------------------------------------
  # topic accepts replies
  # -------------------------------------------------------------------------
  describe "validate_topic_can_reply" do
    it "is invalid when the topic is locked and the current user is not a moderator" do
      topic.update_columns(is_locked: true)
      record = build(:forum_post, topic_id: topic.id)
      expect(record).not_to be_valid
      expect(record.errors[:topic]).to include("does not allow replies")
    end

    it "is valid when the topic is locked but the current user is a moderator" do
      topic.update_columns(is_locked: true)
      CurrentUser.user = create(:moderator_user)
      record = build(:forum_post, topic_id: topic.id)
      expect(record).to be_valid
    end
  end
end
