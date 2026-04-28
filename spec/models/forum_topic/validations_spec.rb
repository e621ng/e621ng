# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ForumTopic Validations                              #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as member"

  # -------------------------------------------------------------------------
  # Title
  # -------------------------------------------------------------------------
  describe "title" do
    it "is invalid when blank" do
      record = build(:forum_topic, title: "")
      expect(record).not_to be_valid
      expect(record.errors[:title]).to be_present
    end

    it "is invalid when longer than 250 characters" do
      record = build(:forum_topic, title: "a" * 251)
      expect(record).not_to be_valid
      expect(record.errors[:title]).to be_present
    end

    it "is valid at exactly 250 characters" do
      record = build(:forum_topic, title: "a" * 250)
      expect(record).to be_valid
    end
  end

  # -------------------------------------------------------------------------
  # Category
  # -------------------------------------------------------------------------
  describe "category" do
    it "is invalid when category_id is nil" do
      record = build(:forum_topic, category_id: nil)
      expect(record).not_to be_valid
      expect(record.errors[:category]).to be_present
    end

    it "is invalid when category_id references a non-existent category" do
      record = build(:forum_topic, category_id: -1)
      expect(record).not_to be_valid
      expect(record.errors[:category]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # Original post presence
  # -------------------------------------------------------------------------
  describe "original_post" do
    it "is invalid without original_post_attributes" do
      record = ForumTopic.new(title: "A topic", category_id: create(:forum_category).id)
      expect(record).not_to be_valid
      expect(record.errors[:original_post]).to be_present
    end
  end

  # -------------------------------------------------------------------------
  # category_allows_creation (create-only)
  # -------------------------------------------------------------------------
  describe "category_allows_creation" do
    let(:restricted_category) { create(:forum_category, can_create: User::Levels::ADMIN) }

    it "is invalid when creating in a category that does not allow the user's level" do
      record = build(:forum_topic, category_id: restricted_category.id)
      expect(record).not_to be_valid
      expect(record.errors[:category]).to include("does not allow new topics")
    end

    it "is not checked on update" do
      # Create the topic as admin so it passes the creation check
      admin = create(:admin_user)
      topic = CurrentUser.scoped(admin) { create(:forum_topic, category_id: restricted_category.id) }

      # Update as admin; category_allows_creation is on: :create only
      topic.title = "Updated title"
      expect(topic).to be_valid
    end
  end
end
