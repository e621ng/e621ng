# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          PoolVersion Search                                 #
# --------------------------------------------------------------------------- #

RSpec.describe PoolVersion do
  include_context "as admin"

  # Each pool creation fires after_save and creates a PoolVersion automatically.
  let!(:pool_a)    { create(:pool) }
  let!(:pool_b)    { create(:pool) }
  let!(:version_a) { pool_a.versions.first }
  let!(:version_b) { pool_b.versions.first }

  # -------------------------------------------------------------------------
  # .for_user
  # -------------------------------------------------------------------------
  describe ".for_user" do
    it "returns versions updated by the given user" do
      expect(PoolVersion.for_user(CurrentUser.user.id)).to include(version_a, version_b)
    end

    it "excludes versions not updated by the given user" do
      other_user = create(:admin_user)
      other_pool = CurrentUser.scoped(other_user, "127.0.0.1") { create(:pool) }
      other_version = other_pool.versions.first
      expect(PoolVersion.for_user(CurrentUser.user.id)).not_to include(other_version)
      expect(PoolVersion.for_user(other_user.id)).to include(other_version)
    end
  end

  # -------------------------------------------------------------------------
  # .default_order
  # -------------------------------------------------------------------------
  describe ".default_order" do
    it "orders by updated_at descending" do
      version_a.update_columns(updated_at: 1.hour.ago)
      result = PoolVersion.default_order.to_a
      a_index = result.index(version_a)
      b_index = result.index(version_b)
      expect(b_index).to be < a_index
    end
  end

  # -------------------------------------------------------------------------
  # .search — pool_id param
  # -------------------------------------------------------------------------
  describe ".search" do
    describe "pool_id param" do
      it "returns versions for a single pool_id" do
        result = PoolVersion.search(pool_id: pool_a.id.to_s)
        expect(result).to include(version_a)
        expect(result).not_to include(version_b)
      end

      it "returns versions for multiple comma-separated pool_ids" do
        result = PoolVersion.search(pool_id: "#{pool_a.id},#{pool_b.id}")
        expect(result).to include(version_a, version_b)
      end

      it "returns all versions when pool_id is absent" do
        result = PoolVersion.search({})
        expect(result).to include(version_a, version_b)
      end
    end

    describe "updater param" do
      it "filters by updater name" do
        other_user = create(:admin_user)
        other_pool = CurrentUser.scoped(other_user, "127.0.0.1") { create(:pool) }
        other_version = other_pool.versions.first

        result = PoolVersion.search("updater_name" => other_user.name)
        expect(result).to include(other_version)
        expect(result).not_to include(version_a)
      end
    end
  end
end
