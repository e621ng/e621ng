# frozen_string_literal: true

require "rails_helper"

RSpec.describe FavoriteFolderMembership do
  include_context "as member"

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:post_record) { create(:post) }
  let(:favorite) { Favorite.create!(user: user, post: post_record) }
  let(:folder) { create(:favorite_folder, user: user) }

  it "is valid when user_id/post_id match the referenced favorite's owner/post" do
    membership = FavoriteFolderMembership.new(user: user, folder: folder, favorite: favorite,
                                              post_id: favorite.post_id, favorite_created_at: favorite.created_at)
    expect(membership).to be_valid
  end

  it "rejects a user_id that does not match the favorite's owner" do
    membership = FavoriteFolderMembership.new(user: other_user, folder: create(:favorite_folder, user: other_user),
                                              favorite: favorite, post_id: favorite.post_id,
                                              favorite_created_at: favorite.created_at)
    expect(membership).not_to be_valid
    expect(membership.errors[:user_id]).to be_present
  end

  it "rejects a post_id that does not match the favorite's post" do
    other_post = create(:post)
    membership = FavoriteFolderMembership.new(user: user, folder: folder, favorite: favorite,
                                              post_id: other_post.id, favorite_created_at: favorite.created_at)
    expect(membership).not_to be_valid
    expect(membership.errors[:post_id]).to be_present
  end

  it "rejects a folder that does not belong to the given user (pre-existing validation, unaffected)" do
    membership = FavoriteFolderMembership.new(user: user, folder: create(:favorite_folder, user: other_user),
                                              favorite: favorite, post_id: favorite.post_id,
                                              favorite_created_at: favorite.created_at)
    expect(membership).not_to be_valid
    expect(membership.errors[:folder]).to be_present
  end

  it "rejects a favorite_created_at that does not match the favorite's created_at" do
    membership = FavoriteFolderMembership.new(user: user, folder: folder, favorite: favorite,
                                              post_id: favorite.post_id, favorite_created_at: favorite.created_at + 1.day)
    expect(membership).not_to be_valid
    expect(membership.errors[:favorite_created_at]).to be_present
  end

  it "rejects a duplicate favorite_id" do
    create(:favorite_folder_membership, user: user, folder: folder, favorite: favorite)
    duplicate = FavoriteFolderMembership.new(user: user, folder: folder, favorite: favorite,
                                             post_id: favorite.post_id, favorite_created_at: favorite.created_at)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:favorite_id]).to be_present
  end

  describe "FavoriteFolderManager.move!'s real write path" do
    it "always produces a consistent membership row, since user_id/post_id are read directly off the trusted favorite/user objects, never supplied independently" do
      FavoriteManager.add!(user: user, post: post_record)
      created_favorite = Favorite.for_user(user.id).find_by(post_id: post_record.id)

      FavoriteFolderManager.move!(user: user, post: post_record, destination_folder_id: folder.id)

      membership = FavoriteFolderMembership.find_by(favorite_id: created_favorite.id)
      expect(membership.user_id).to eq(created_favorite.user_id)
      expect(membership.post_id).to eq(created_favorite.post_id)
    end
  end
end
