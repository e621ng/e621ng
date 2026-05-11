# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumTopic Instance Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  let(:member)          { create(:user) }
  let(:moderator)       { create(:moderator_user) }
  let(:admin)           { create(:admin_user) }
  let(:other)           { create(:user) }
  let(:category)        { create(:forum_category) }
  let(:admin_category)  { create(:forum_category, can_view: User::Levels::ADMIN) }

  before do
    CurrentUser.user = member
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  def make_topic(overrides = {})
    create(:forum_topic, category_id: category.id, **overrides)
  end

  # -------------------------------------------------------------------------
  # #category_name
  # -------------------------------------------------------------------------
  describe "#category_name" do
    it "returns the associated category's name" do
      topic = make_topic
      expect(topic.category_name).to eq(category.name)
    end

    it "returns '(Unknown)' when the category association is nil" do
      topic = make_topic
      topic.category = nil
      expect(topic.category_name).to eq("(Unknown)")
    end
  end

  # -------------------------------------------------------------------------
  # #can_access?
  # -------------------------------------------------------------------------
  describe "#can_access?" do
    it "returns false for blank users" do
      topic = make_topic
      expect(topic.can_access?(nil)).to be false
    end

    it "is visible to a member when not hidden and category level allows it" do
      topic = make_topic
      expect(topic.can_access?(member)).to be true
    end

    it "is not visible to an unrelated member when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.can_access?(other)).to be false
    end

    it "is visible to the creator even when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: member.id)
      expect(topic.can_access?(member)).to be true
    end

    it "is visible to a moderator even when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.can_access?(moderator)).to be true
    end

    it "is not visible to a member when category requires a higher level" do
      restricted = create(:forum_category, can_view: User::Levels::MODERATOR)
      topic = create(:forum_topic)
      topic.update_columns(category_id: restricted.id)
      expect(topic.can_access?(member)).to be false
    end

    it "is not visible when the category is invalid" do
      topic = make_topic
      topic.update_columns(category_id: 9999)
      expect(topic.can_access?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_edit?
  # -------------------------------------------------------------------------
  describe "#can_edit?" do
    it "allows the creator to edit their own visible topic" do
      topic = make_topic
      topic.update_columns(creator_id: member.id)
      expect(topic.can_edit?(member)).to be true
    end

    it "allows a moderator to edit any visible topic" do
      topic = make_topic
      expect(topic.can_edit?(moderator)).to be true
    end

    it "denies a non-creator non-moderator" do
      topic = make_topic
      expect(topic.can_edit?(other)).to be false
    end

    it "denies the creator when the topic is hidden (not visible to them)" do
      # A topic hidden by someone else — the creator is a different user
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: other.id)
      # `member` is not creator and not moderator, so can_access? is false → can_edit? false
      expect(topic.can_edit?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_reply?
  # -------------------------------------------------------------------------
  describe "#can_reply?" do
    it "returns true when user level meets the category requirement" do
      topic = make_topic
      expect(topic.can_reply?(member)).to be true
    end

    it "returns false when user level is below the category requirement" do
      restricted = create(:forum_category, can_reply: User::Levels::MODERATOR)
      topic = create(:forum_topic)
      topic.update_columns(category_id: restricted.id)
      expect(topic.can_reply?(member)).to be false
    end

    it "returns false when the category is invalid" do
      topic = make_topic
      topic.update_columns(category_id: 9999)
      expect(topic.can_reply?(member)).to be false
    end

    it "returns false when the topic is locked and the user cannot lock" do
      topic = make_topic
      topic.update_columns(is_locked: true)
      expect(topic.can_reply?(member)).to be false
    end

    it "returns true when the topic is locked but the user can lock" do
      topic = make_topic
      topic.update_columns(is_locked: true)
      expect(topic.can_reply?(moderator)).to be true
    end
  end

  # -------------------------------------------------------------------------
  # #can_hide?
  # -------------------------------------------------------------------------
  describe "#can_hide?" do
    it "allows the creator to hide the topic" do
      topic = make_topic
      topic.update_columns(creator_id: member.id)
      expect(topic.can_hide?(member)).to be true
    end

    it "allows a moderator to hide any topic" do
      topic = make_topic
      expect(topic.can_hide?(moderator)).to be true
    end

    it "denies an unrelated member" do
      topic = make_topic
      expect(topic.can_hide?(other)).to be false
    end

    it "denies the creator when the original post cannot be hidden" do
      topic = make_topic
      topic.update_columns(creator_id: member.id)
      topic.original_post.update_columns(warning_type: 1)
      expect(topic.can_hide?(member)).to be false
    end

    it "denies the creator if the topic category changed to a restricted one" do
      restricted = create(:forum_category, can_view: User::Levels::MODERATOR)
      topic = make_topic
      topic.update_columns(creator_id: member.id, category_id: restricted.id)
      expect(topic.can_hide?(member)).to be false
    end

    it "returns false when the original post is missing" do
      topic = make_topic
      topic.original_post.destroy
      topic.reload
      expect(topic.can_hide?(member)).to be false
    end

    it "returns false if the topic's creator is different to the original post's creator" do
      # This is virtually impossible in production, but we should handle it gracefully just in case.
      topic = make_topic
      topic.update_columns(creator_id: other.id)
      topic.original_post.update_columns(creator_id: member.id)
      expect(topic.can_hide?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_unhide?
  # -------------------------------------------------------------------------
  describe "#can_unhide?" do
    it "allows a moderator to unhide any topic" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.can_unhide?(moderator)).to be true
    end

    it "denies a regular member" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.can_unhide?(member)).to be false
    end

    it "denies if the topic is hidden from the user" do
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: other.id, category_id: admin_category.id)
      expect(topic.can_unhide?(moderator)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_sticky?
  # -------------------------------------------------------------------------
  describe "#can_sticky?" do
    it "allows a moderator to sticky any topic" do
      topic = make_topic
      expect(topic.can_sticky?(moderator)).to be true
    end

    it "denies a regular member" do
      topic = make_topic
      expect(topic.can_sticky?(member)).to be false
    end

    it "denies when the topic is hidden from the user" do
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: other.id, category_id: admin_category.id)
      expect(topic.can_sticky?(moderator)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_lock?
  # -------------------------------------------------------------------------
  describe "#can_lock?" do
    it "allows a moderator to lock any topic" do
      topic = make_topic
      expect(topic.can_lock?(moderator)).to be true
    end

    it "denies a regular member" do
      topic = make_topic
      expect(topic.can_lock?(member)).to be false
    end

    it "denies when the topic is hidden from the user" do
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: other.id, category_id: admin_category.id)
      expect(topic.can_lock?(moderator)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #can_destroy?
  # -------------------------------------------------------------------------
  describe "#can_destroy?" do
    it "allows an admin to destroy a topic" do
      topic = make_topic
      expect(topic.can_destroy?(admin)).to be true
    end

    it "denies a moderator" do
      topic = make_topic
      expect(topic.can_destroy?(moderator)).to be false
    end

    it "denies a regular member" do
      topic = make_topic
      expect(topic.can_destroy?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #hide! / #unhide!
  # -------------------------------------------------------------------------
  describe "#hide!" do
    it "sets is_hidden to true" do
      topic = make_topic
      expect { topic.hide! }.to change { topic.reload.is_hidden }.from(false).to(true)
    end
  end

  describe "#unhide!" do
    it "sets is_hidden to false" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect { topic.unhide! }.to change { topic.reload.is_hidden }.from(true).to(false)
    end
  end

  # -------------------------------------------------------------------------
  # #last_page
  # -------------------------------------------------------------------------
  describe "#last_page" do
    it "returns 0 when there are no responses" do
      topic = make_topic
      topic.update_columns(response_count: 0)
      expect(topic.last_page).to eq(0)
    end

    it "calculates the correct last page based on response_count" do
      per_page = Danbooru.config.records_per_page
      topic = make_topic
      topic.update_columns(response_count: per_page + 1)
      expect(topic.last_page).to eq(2)
    end
  end

  # -------------------------------------------------------------------------
  # #update_original_post (via after_update)
  # -------------------------------------------------------------------------
  describe "#update_original_post" do
    it "updates the original post's updater_id to CurrentUser after a topic update" do
      topic = make_topic
      original_post = topic.original_post

      CurrentUser.user = moderator
      topic.update!(title: "Changed title")

      expect(original_post.reload.updater_id).to eq(moderator.id)
    end

    it "refreshes the original post's updated_at after a topic update" do
      topic = make_topic
      original_post = topic.original_post
      original_post.update_columns(updated_at: 1.hour.ago)
      old_updated_at = original_post.updated_at

      topic.update!(title: "Changed title")

      expect(original_post.reload.updated_at).to be > old_updated_at
    end
  end

  # -------------------------------------------------------------------------
  # #user_subscription
  # -------------------------------------------------------------------------
  describe "#user_subscription" do
    it "returns nil when the user has no subscription" do
      topic = make_topic
      expect(topic.user_subscription(member)).to be_nil
    end

    it "returns the subscription record when one exists" do
      topic = make_topic
      subscription = ForumSubscription.create!(user: member, forum_topic: topic, last_read_at: Time.now)
      expect(topic.user_subscription(member)).to eq(subscription)
    end
  end
end
