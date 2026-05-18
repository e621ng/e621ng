# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Pool Version Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # after_save :create_version — PoolVersion is enqueued when watched
  # attributes change
  # -------------------------------------------------------------------------
  describe "after_save :create_version" do
    it "creates a PoolVersion when the pool is created (name changes on create)" do
      expect { create(:pool) }.to change(PoolVersion, :count).by(1)
    end

    it "creates a PoolVersion when name changes" do
      pool = create(:pool)
      expect do
        pool.update!(name: "new_unique_name_#{SecureRandom.hex(4)}")
      end.to change(PoolVersion, :count).by(1)
    end

    it "creates a PoolVersion when description changes" do
      pool = create(:pool)
      expect do
        pool.update!(description: "updated description")
      end.to change(PoolVersion, :count).by(1)
    end

    it "creates a PoolVersion when is_active changes" do
      pool = create(:pool)
      expect do
        pool.update!(is_active: !pool.is_active)
      end.to change(PoolVersion, :count).by(1)
    end

    it "creates a PoolVersion when category changes" do
      member = create(:user, created_at: 30.days.ago)
      CurrentUser.user = member
      CurrentUser.ip_addr = "127.0.0.1"

      post = create(:post)
      pool = create(:pool, post_ids: [post.id], category: "series")
      expect do
        pool.update!(category: "collection")
      end.to change(PoolVersion, :count).by(1)
    end

    it "does NOT create a PoolVersion when no watched attribute changes" do
      pool = create(:pool)
      # Reload to clear dirty state; then re-save without changes
      pool.reload
      expect do
        # touch a non-watched attribute by reloading and saving with no changes
        pool.save!
      end.not_to change(PoolVersion, :count)
    end
  end

  # -------------------------------------------------------------------------
  # #saved_change_to_watched_attributes?
  # -------------------------------------------------------------------------
  describe "#saved_change_to_watched_attributes?" do
    it "returns true after saving a name change" do
      pool = create(:pool)
      pool.update!(name: "watched_name_change_#{SecureRandom.hex(4)}")
      expect(pool.saved_change_to_watched_attributes?).to be true
    end

    it "returns true after saving a description change" do
      pool = create(:pool)
      pool.update!(description: "watched description change")
      expect(pool.saved_change_to_watched_attributes?).to be true
    end

    it "returns true after saving an is_active change" do
      pool = create(:pool)
      pool.update!(is_active: !pool.is_active)
      expect(pool.saved_change_to_watched_attributes?).to be true
    end

    it "returns false immediately after a no-op save" do
      pool = create(:pool)
      pool.reload
      pool.save!
      expect(pool.saved_change_to_watched_attributes?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #revert_to!
  # -------------------------------------------------------------------------
  describe "#revert_to!" do
    it "restores name, description, post_ids, is_active, and category from a version" do
      post1 = create(:post)
      post2 = create(:post)
      pool = create(:pool, name: "original_name", description: "original desc",
                           post_ids: [post1.id, post2.id], is_active: true, category: "series")
      version = pool.versions.last

      # Mutate the pool
      new_name = "mutated_name_#{SecureRandom.hex(4)}"
      pool.update!(name: new_name, description: "mutated desc", is_active: false, category: "collection")

      pool.revert_to!(version)
      pool.reload

      expect(pool.name).to eq("original_name")
      expect(pool.description).to eq("original desc")
      expect(pool.post_ids).to eq([post1.id, post2.id])
      expect(pool.is_active).to be true
      expect(pool.category).to eq("series")
    end

    it "raises Pool::RevertError when the version belongs to a different pool" do
      pool_a = create(:pool)
      pool_b = create(:pool)
      version_b = pool_b.versions.last

      expect { pool_a.revert_to!(version_b) }.to raise_error(Pool::RevertError)
    end
  end
end
