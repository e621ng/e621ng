# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagTypeVersion do
  describe "tag versioning" do
    include_context "as member"

    it "creates a new version when the tag type is updated" do
      tag = create(:tag, category: 0)
      creator = CurrentUser.user
      tag.category = 1
      tag.save!

      version = TagTypeVersion.last
      expect(version.tag_id).to eq(tag.id)
      expect(version.old_type).to eq(0)
      expect(version.new_type).to eq(1)
      expect(version.creator_id).to eq(creator.id)
    end
  end

  describe "search methods" do
    it "returns versions for a specific tag" do
      admin = create(:user)

      tag1 = create(:tag)
      tag2 = create(:tag)

      CurrentUser.scoped(admin) do
        tag1.category = 1
        tag1.save!
        tag2.category = 1
        tag2.save!
      end

      version1 = TagTypeVersion.find_by(tag_id: tag1.id)
      version2 = TagTypeVersion.find_by(tag_id: tag2.id)

      expect(TagTypeVersion.search(tag: tag1.name)).to include(version1)
      expect(TagTypeVersion.search(tag: tag1.name)).not_to include(version2)
    end

    it "returns versions created by a specific user" do
      user1 = create(:user)
      user2 = create(:user)
      tag = create(:tag)

      CurrentUser.scoped(user1) do
        tag.category = 1
        tag.save!
      end

      CurrentUser.scoped(user2) do
        tag.category = 3
        tag.save!
      end

      version1 = TagTypeVersion.find_by(tag_id: tag.id, old_type: 0, new_type: 1)
      version2 = TagTypeVersion.find_by(tag_id: tag.id, old_type: 1, new_type: 2)

      # Known bug: ApplicationController#with_resolved_user_ids only accepts string keys and values
      search_results = TagTypeVersion.search(user_id: user1.id)
      expect(search_results).to include(version1)
      expect(search_results).not_to include(version2)
    end
  end
end
