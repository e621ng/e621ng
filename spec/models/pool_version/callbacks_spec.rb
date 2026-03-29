# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         PoolVersion Callbacks                               #
# --------------------------------------------------------------------------- #

RSpec.describe PoolVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # fill_version (before_validation on: :create)
  # -------------------------------------------------------------------------
  describe "fill_version" do
    it "assigns version 1 to the first pool_version for a pool" do
      pool = create(:pool)
      version = pool.versions.first
      expect(version.version).to eq(1)
    end

    it "increments the version for each subsequent pool_version" do
      pool = create(:pool)
      pool.update!(description: "updated description")
      versions = pool.versions.order(:version)
      expect(versions.map(&:version)).to eq([1, 2])
    end
  end

  # -------------------------------------------------------------------------
  # fill_changes (before_validation on: :create)
  # -------------------------------------------------------------------------
  describe "fill_changes" do
    describe "first version (no previous)" do
      it "sets added_post_ids to all post_ids" do
        pool = create(:pool, post_ids: [1, 2, 3])
        version = pool.versions.first
        expect(version.added_post_ids).to eq([1, 2, 3])
      end

      it "sets removed_post_ids to an empty array" do
        pool = create(:pool, post_ids: [1, 2])
        version = pool.versions.first
        expect(version.removed_post_ids).to eq([])
      end

      it "sets name_changed to true" do
        pool = create(:pool)
        version = pool.versions.first
        expect(version.name_changed).to be true
      end

      it "sets description_changed to true" do
        pool = create(:pool)
        version = pool.versions.first
        expect(version.description_changed).to be true
      end
    end

    describe "subsequent version (has previous)" do
      it "records newly added post_ids" do
        pool = create(:pool, post_ids: [1, 2])
        pool.update!(post_ids: [1, 2, 3])
        version = pool.versions.last
        expect(version.added_post_ids).to eq([3])
      end

      it "records removed post_ids" do
        pool = create(:pool, post_ids: [1, 2, 3])
        pool.update!(post_ids: [1, 3])
        version = pool.versions.last
        expect(version.removed_post_ids).to eq([2])
      end

      it "sets name_changed to true when name differs from previous" do
        pool = create(:pool, name: "original_name_#{SecureRandom.hex(4)}")
        pool.update!(name: "updated_name_#{SecureRandom.hex(4)}")
        version = pool.versions.last
        expect(version.name_changed).to be true
      end

      it "sets name_changed to false when name is unchanged" do
        pool = create(:pool)
        pool.update!(description: "something new")
        version = pool.versions.last
        expect(version.name_changed).to be false
      end

      it "sets description_changed to true when description differs from previous" do
        pool = create(:pool, description: "original desc")
        pool.update!(description: "new desc")
        version = pool.versions.last
        expect(version.description_changed).to be true
      end

      it "sets description_changed to false when description is unchanged" do
        pool = create(:pool, description: "same desc")
        pool.update!(name: "some_other_name_#{SecureRandom.hex(4)}")
        version = pool.versions.last
        expect(version.description_changed).to be false
      end
    end
  end
end
