# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumCategory do
  describe "validations" do
    include_context "as admin"

    it "has unique name" do
      create(:forum_category, name: "General Discussion")
      duplicate = build(:forum_category, name: "general discussion")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "methods" do
    it "reassigns topics to the default category when destroyed" do
      default_category = ForumCategory.find(1) # Seeded category, always has ID 1

      CurrentUser.scoped(create(:admin_user)) do
        category = create(:forum_category)

        topic1 = create(:forum_topic, category_id: category.id, original_post_attributes: { body: "This is the original post." })
        topic2 = create(:forum_topic, category_id: category.id, original_post_attributes: { body: "This is another original post." })

        expect(ForumTopic.where(id: [topic1.id, topic2.id]).pluck(:category_id)).to eq([category.id, category.id])

        category.destroy
        expect(ForumTopic.where(id: [topic1.id, topic2.id]).pluck(:category_id)).to eq([default_category.id, default_category.id])
      end
    end

    it "can reverse mapping" do
      category0 = ForumCategory.find(1) # Seeded category, always has ID 1
      category1 = create(:forum_category, name: "Category 1", cat_order: 2)
      category2 = create(:forum_category, name: "Category 2", cat_order: 1)

      expect(ForumCategory.reverse_mapping).to eq([["Category 2", category2.id], ["Category 1", category1.id], [category0.name, category0.id]])
    end

    it "can get ordered categories" do
      category0 = ForumCategory.find(1) # Seeded category, always has ID 1 and cat_order nil
      category1 = create(:forum_category, name: "Category 1", cat_order: 2)
      category2 = create(:forum_category, name: "Category 2", cat_order: 1)

      expect(ForumCategory.ordered_categories).to eq([category2, category1, category0])
    end

    it "can get visible categories" do
      category0 = ForumCategory.find(1) # Seeded category, always has ID 1 and can_view 0

      member = create(:user)
      janitor = create(:janitor_user)
      moderator = create(:moderator_user)
      admin = create(:admin_user)

      member_category = create(:forum_category, name: "Member Category", can_view: User::Levels::MEMBER)
      janitor_category = create(:forum_category, name: "Janitor Category", can_view: User::Levels::JANITOR)
      moderator_category = create(:forum_category, name: "Moderator Category", can_view: User::Levels::MODERATOR)
      admin_category = create(:forum_category, name: "Admin Category", can_view: User::Levels::ADMIN)

      expect(ForumCategory.visible(member)).to eq([category0, member_category])
      expect(ForumCategory.visible(janitor)).to eq([category0, member_category, janitor_category])
      expect(ForumCategory.visible(moderator)).to eq([category0, member_category, janitor_category, moderator_category])
      expect(ForumCategory.visible(admin)).to eq([category0, member_category, janitor_category, moderator_category, admin_category])
    end
  end

  describe "access methods" do
    it "#can_access" do
      member = create(:user)
      janitor = create(:janitor_user)
      moderator = create(:moderator_user)
      admin = create(:admin_user)

      member_category = create(:forum_category, can_view: User::Levels::MEMBER)
      janitor_category = create(:forum_category, can_view: User::Levels::JANITOR)
      moderator_category = create(:forum_category, can_view: User::Levels::MODERATOR)
      admin_category = create(:forum_category, can_view: User::Levels::ADMIN)

      expect(member_category.can_access?(member)).to be true
      expect(member_category.can_access?(janitor)).to be true
      expect(member_category.can_access?(moderator)).to be true
      expect(member_category.can_access?(admin)).to be true

      expect(janitor_category.can_access?(member)).to be false
      expect(janitor_category.can_access?(janitor)).to be true
      expect(janitor_category.can_access?(moderator)).to be true
      expect(janitor_category.can_access?(admin)).to be true

      expect(moderator_category.can_access?(member)).to be false
      expect(moderator_category.can_access?(janitor)).to be false
      expect(moderator_category.can_access?(moderator)).to be true
      expect(moderator_category.can_access?(admin)).to be true

      expect(admin_category.can_access?(member)).to be false
      expect(admin_category.can_access?(janitor)).to be false
      expect(admin_category.can_access?(moderator)).to be false
      expect(admin_category.can_access?(admin)).to be true
    end

    it "#can_create" do
      member = create(:user)
      janitor = create(:janitor_user)
      moderator = create(:moderator_user)
      admin = create(:admin_user)

      member_category = create(:forum_category, can_create: User::Levels::MEMBER)
      janitor_category = create(:forum_category, can_create: User::Levels::JANITOR)
      moderator_category = create(:forum_category, can_create: User::Levels::MODERATOR)
      admin_category = create(:forum_category, can_create: User::Levels::ADMIN)

      expect(member_category.can_create?(member)).to be true
      expect(member_category.can_create?(janitor)).to be true
      expect(member_category.can_create?(moderator)).to be true
      expect(member_category.can_create?(admin)).to be true

      expect(janitor_category.can_create?(member)).to be false
      expect(janitor_category.can_create?(janitor)).to be true
      expect(janitor_category.can_create?(moderator)).to be true
      expect(janitor_category.can_create?(admin)).to be true

      expect(moderator_category.can_create?(member)).to be false
      expect(moderator_category.can_create?(janitor)).to be false
      expect(moderator_category.can_create?(moderator)).to be true
      expect(moderator_category.can_create?(admin)).to be true

      expect(admin_category.can_create?(member)).to be false
      expect(admin_category.can_create?(janitor)).to be false
      expect(admin_category.can_create?(moderator)).to be false
      expect(admin_category.can_create?(admin)).to be true
    end

    it "#can_reply" do
      member = create(:user)
      janitor = create(:janitor_user)
      moderator = create(:moderator_user)
      admin = create(:admin_user)

      member_category = create(:forum_category, can_reply: User::Levels::MEMBER)
      janitor_category = create(:forum_category, can_reply: User::Levels::JANITOR)
      moderator_category = create(:forum_category, can_reply: User::Levels::MODERATOR)
      admin_category = create(:forum_category, can_reply: User::Levels::ADMIN)

      expect(member_category.can_reply?(member)).to be true
      expect(member_category.can_reply?(janitor)).to be true
      expect(member_category.can_reply?(moderator)).to be true
      expect(member_category.can_reply?(admin)).to be true

      expect(janitor_category.can_reply?(member)).to be false
      expect(janitor_category.can_reply?(janitor)).to be true
      expect(janitor_category.can_reply?(moderator)).to be true
      expect(janitor_category.can_reply?(admin)).to be true

      expect(moderator_category.can_reply?(member)).to be false
      expect(moderator_category.can_reply?(janitor)).to be false
      expect(moderator_category.can_reply?(moderator)).to be true
      expect(moderator_category.can_reply?(admin)).to be true

      expect(admin_category.can_reply?(member)).to be false
      expect(admin_category.can_reply?(janitor)).to be false
      expect(admin_category.can_reply?(moderator)).to be false
      expect(admin_category.can_reply?(admin)).to be true
    end
  end
end
