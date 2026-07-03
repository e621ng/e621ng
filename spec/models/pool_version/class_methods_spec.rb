# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       PoolVersion Class Methods                             #
# --------------------------------------------------------------------------- #

RSpec.describe PoolVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .calculate_version
  # -------------------------------------------------------------------------
  describe ".calculate_version" do
    it "returns 1 when no versions exist for the pool" do
      pool = create(:pool)
      fake_pool_id = pool.id + 9999
      expect(PoolVersion.calculate_version(fake_pool_id)).to eq(1)
    end

    it "returns one more than the current maximum version" do
      pool = create(:pool)
      # Pool creation fires after_save → version 1 already exists
      expect(PoolVersion.calculate_version(pool.id)).to eq(2)
    end
  end

  # -------------------------------------------------------------------------
  # .queue
  # -------------------------------------------------------------------------
  describe ".queue" do
    it "creates a PoolVersion record" do
      posts = create_list(:post, 2)
      pool = create(:pool, post_ids: posts.map(&:id), description: "queue desc", name: "queue_test_pool_#{SecureRandom.hex(4)}")
      # First version was already created on pool creation; force another via queue directly
      updater = CurrentUser.user
      expect do
        PoolVersion.queue(pool, updater, "10.0.0.1")
      end.to change(PoolVersion, :count).by(1)
    end

    it "snapshots pool_id, post_ids, description, name, is_active, and category" do
      posts = create_list(:post, 2)
      pool = create(:pool, post_ids: posts.map(&:id), description: "snap desc",
                           name: "snapshot_pool_#{SecureRandom.hex(4)}", is_active: true, category: "series")
      updater = CurrentUser.user
      PoolVersion.queue(pool, updater, "10.0.0.1")
      pv = PoolVersion.where(pool_id: pool.id).order(:version).last
      expect(pv.post_ids).to eq(posts.map(&:id))
      expect(pv.description).to eq("snap desc")
      expect(pv.name).to eq(pool.name)
      expect(pv.is_active).to be true
      expect(pv.category).to eq("series")
    end

    it "records the updater and IP address" do
      pool = create(:pool)
      updater = CurrentUser.user
      PoolVersion.queue(pool, updater, "192.168.1.1")
      pv = PoolVersion.where(pool_id: pool.id).order(:version).last
      expect(pv.updater_id).to eq(updater.id)
      expect(pv.updater_ip_addr.to_s).to eq("192.168.1.1")
    end
  end
end
