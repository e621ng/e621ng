# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumTopic Instance Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  let(:member)    { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }
  let(:other)     { create(:user) }
  let(:category)  { create(:forum_category) }

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
  # #visible?
  # -------------------------------------------------------------------------
  describe "#visible?" do
    it "is visible to a member when not hidden and category level allows it" do
      topic = make_topic
      expect(topic.visible?(member)).to be true
    end

    it "is not visible to an unrelated member when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.visible?(other)).to be false
    end

    it "is visible to the creator even when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: member.id)
      expect(topic.visible?(member)).to be true
    end

    it "is visible to a moderator even when hidden" do
      topic = make_topic
      topic.update_columns(is_hidden: true)
      expect(topic.visible?(moderator)).to be true
    end

    it "is not visible to a member when category requires a higher level" do
      restricted = create(:forum_category, can_view: User::Levels::MODERATOR)
      topic = CurrentUser.scoped(moderator) { create(:forum_topic, category_id: restricted.id) }
      expect(topic.visible?(member)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #editable_by?
  # -------------------------------------------------------------------------
  describe "#editable_by?" do
    it "allows the creator to edit their own visible topic" do
      topic = make_topic
      topic.update_columns(creator_id: member.id)
      expect(topic.editable_by?(member)).to be true
    end

    it "allows a moderator to edit any visible topic" do
      topic = make_topic
      expect(topic.editable_by?(moderator)).to be true
    end

    it "denies a non-creator non-moderator" do
      topic = make_topic
      expect(topic.editable_by?(other)).to be false
    end

    it "denies the creator when the topic is hidden (not visible to them)" do
      # A topic hidden by someone else — the creator is a different user
      topic = make_topic
      topic.update_columns(is_hidden: true, creator_id: other.id)
      # `member` is not creator and not moderator, so visible? is false → editable_by? false
      expect(topic.editable_by?(member)).to be false
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
      topic = CurrentUser.scoped(moderator) { create(:forum_topic, category_id: restricted.id) }
      expect(topic.can_reply?(member)).to be false
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
  end

  # -------------------------------------------------------------------------
  # #can_delete?
  # -------------------------------------------------------------------------
  describe "#can_delete?" do
    it "allows an admin to delete a topic" do
      topic = make_topic
      expect(topic.can_delete?(admin)).to be true
    end

    it "denies a moderator" do
      topic = make_topic
      expect(topic.can_delete?(moderator)).to be false
    end

    it "denies a regular member" do
      topic = make_topic
      expect(topic.can_delete?(member)).to be false
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
