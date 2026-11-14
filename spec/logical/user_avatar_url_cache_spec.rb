# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserAvatarUrlCache do
  describe "#key" do
    it "generates a cache key based on the user ID" do
      expect(UserAvatarUrlCache.key(123)).to eq("user_avatar_url:123")
    end
  end

  describe "#get" do
    include_context "as member"

    let(:post) { create(:post) }
    let(:deleted_post) { create(:deleted_post) }

    it "returns nil if the user is blank" do
      expect(UserAvatarUrlCache.get(nil)).to be_nil
    end

    it "returns nil if the user has no avatar" do
      user = build(:user)
      expect(UserAvatarUrlCache.get(user)).to be_nil
    end

    it "returns the correct URLs for a cropped avatar" do
      sm = Danbooru.config.storage_manager
      user = build(:user, avatar_id: 10, bit_prefs: User.flag_value_for("has_cropped_avatar"), updated_at: Time.at(1_000_000))
      expect(UserAvatarUrlCache.get(user)).to eq([
        sm.avatar_url(user.id, "webp", timestamp: user.updated_at.to_i),
        sm.avatar_url(user.id, "jpg", timestamp: user.updated_at.to_i),
      ])
    end

    it "caches the preview URL for an uncropped avatar" do
      user = create(:user, avatar_id: post.id)

      expect(UserAvatarUrlCache.get(user)).to eq(post.preview_file_url_pair)
      expect(Cache.fetch(UserAvatarUrlCache.key(user.id))).to eq(post.preview_file_url_pair)
    end

    it "caches nil for a deleted avatar post" do
      user = create(:user, avatar_id: deleted_post.id)

      expect(UserAvatarUrlCache.get(user)).to be_nil
      expect(Cache.fetch(UserAvatarUrlCache.key(user.id))).to be_nil
    end
  end

  describe "#invalidate" do
    it "deletes the cache entry for the given user ID" do
      user = create(:user, avatar_id: 10)
      Cache.write(UserAvatarUrlCache.key(user.id), "cached value")
      UserAvatarUrlCache.invalidate(user.id)
      expect(Cache.fetch(UserAvatarUrlCache.key(user.id))).to be_nil
    end
  end

  context "with an e926 profile" do
    include_context "with e926 site profile"

    it "keys entries per site, leaving the primary key unchanged" do
      expect(UserAvatarUrlCache.key(123)).to eq("user_avatar_url:123")
      CurrentSite.with("e926") { expect(UserAvatarUrlCache.key(123)).to eq("user_avatar_url:123:e926") }
    end

    it "invalidates every site's entry" do
      Cache.write("user_avatar_url:5", "a")
      Cache.write("user_avatar_url:5:e926", "b")
      UserAvatarUrlCache.invalidate(5)
      expect(Cache.fetch("user_avatar_url:5")).to be_nil
      expect(Cache.fetch("user_avatar_url:5:e926")).to be_nil
    end
  end
end
