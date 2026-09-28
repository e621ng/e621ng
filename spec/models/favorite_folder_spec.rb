# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteFolder do
  include_context "as member"

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "validations" do
    it "allows a root-level folder" do
      folder = build(:favorite_folder, user: user, parent: nil)
      expect(folder).to be_valid
    end

    it "allows a nested folder" do
      parent = create(:favorite_folder, user: user)
      child = build(:favorite_folder, user: user, parent: parent)
      expect(child).to be_valid
    end

    it "allows folders nested several levels deep" do
      a = create(:favorite_folder, user: user, name: "a")
      b = create(:favorite_folder, user: user, name: "b", parent: a)
      c = build(:favorite_folder, user: user, name: "c", parent: b)
      expect(c).to be_valid
    end

    it "rejects a parent folder owned by another user" do
      other_folder = create(:favorite_folder, user: other_user)
      folder = build(:favorite_folder, user: user, parent: other_folder)
      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to be_present
    end

    it "rejects a blank name" do
      folder = build(:favorite_folder, user: user, name: "")
      expect(folder).not_to be_valid
    end

    it "rejects a duplicate name (case-insensitive) among root-level siblings" do
      create(:favorite_folder, user: user, name: "Memes")
      dupe = build(:favorite_folder, user: user, name: "memes")
      expect(dupe).not_to be_valid
    end

    it "rejects a duplicate name (case-insensitive) among siblings under the same parent" do
      parent = create(:favorite_folder, user: user)
      create(:favorite_folder, user: user, parent: parent, name: "Memes")
      dupe = build(:favorite_folder, user: user, parent: parent, name: "MEMES")
      expect(dupe).not_to be_valid
    end

    it "allows the same name under different parents" do
      parent_a = create(:favorite_folder, user: user, name: "A")
      parent_b = create(:favorite_folder, user: user, name: "B")
      create(:favorite_folder, user: user, parent: parent_a, name: "Memes")
      sibling_in_b = build(:favorite_folder, user: user, parent: parent_b, name: "Memes")
      expect(sibling_in_b).to be_valid
    end

    it "allows the same name at root and nested under a different folder" do
      parent = create(:favorite_folder, user: user, name: "Other")
      create(:favorite_folder, user: user, name: "Memes")
      nested = build(:favorite_folder, user: user, parent: parent, name: "Memes")
      expect(nested).to be_valid
    end

    it "rejects setting a folder as its own parent" do
      folder = create(:favorite_folder, user: user)
      folder.parent = folder
      expect(folder).not_to be_valid
      expect(folder.errors[:parent]).to be_present
    end

    it "rejects setting a folder's parent to one of its own descendants" do
      grandparent = create(:favorite_folder, user: user, name: "a")
      parent = create(:favorite_folder, user: user, name: "b", parent: grandparent)
      child = create(:favorite_folder, user: user, name: "c", parent: parent)

      grandparent.parent = child
      expect(grandparent).not_to be_valid
      expect(grandparent.errors[:parent]).to be_present
    end
  end

  describe "associations" do
    it "has many children ordered case-insensitively by name" do
      parent = create(:favorite_folder, user: user)
      create(:favorite_folder, user: user, parent: parent, name: "banana")
      create(:favorite_folder, user: user, parent: parent, name: "Apple")
      expect(parent.children.map(&:name)).to eq(%w[Apple banana])
    end

    it "restricts destroy when it has memberships attached" do
      folder = create(:favorite_folder, user: user)
      post = create(:post)
      favorite = Favorite.create!(user: user, post: post)
      create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)
      expect { folder.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end

    it "restricts destroy when it has child folders" do
      folder = create(:favorite_folder, user: user)
      create(:favorite_folder, user: user, parent: folder)
      expect { folder.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end
end
