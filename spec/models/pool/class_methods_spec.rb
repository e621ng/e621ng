# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Pool Class Methods                                #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # .normalize_name
  # -------------------------------------------------------------------------
  describe ".normalize_name" do
    it "collapses consecutive underscores into one" do
      expect(Pool.normalize_name("my__pool")).to eq("my_pool")
    end

    it "collapses consecutive spaces into one underscore" do
      expect(Pool.normalize_name("my  pool")).to eq("my_pool")
    end

    it "collapses a mix of spaces and underscores" do
      expect(Pool.normalize_name("my _ pool")).to eq("my_pool")
    end

    it "strips a leading underscore" do
      expect(Pool.normalize_name("_leading")).to eq("leading")
    end

    it "strips a trailing underscore" do
      expect(Pool.normalize_name("trailing_")).to eq("trailing")
    end

    it "returns an already-normalized name unchanged" do
      expect(Pool.normalize_name("already_normal")).to eq("already_normal")
    end
  end

  # -------------------------------------------------------------------------
  # .name_to_id
  # -------------------------------------------------------------------------
  describe ".name_to_id" do
    it "returns the id when given a numeric string matching an id" do
      pool = create(:pool)
      expect(Pool.name_to_id(pool.id.to_s)).to eq(pool.id)
    end

    it "returns the id when given the pool's name string" do
      pool = create(:pool, name: "name_to_id_test_pool")
      expect(Pool.name_to_id("name_to_id_test_pool")).to eq(pool.id)
    end

    it "is case-insensitive when looking up by name" do
      pool = create(:pool, name: "case_pool")
      expect(Pool.name_to_id("CASE_POOL")).to eq(pool.id)
    end

    it "returns 0 when no pool has the given name" do
      expect(Pool.name_to_id("nonexistent_pool_xyz")).to eq(0)
    end
  end

  # -------------------------------------------------------------------------
  # .find_by_name
  # -------------------------------------------------------------------------
  describe ".find_by_name" do
    it "finds a pool by numeric id string" do
      pool = create(:pool)
      # NOTE: Pool.find_by_name is a custom method, not a dynamic finder
      expect(Pool.find_by_name(pool.id.to_s)).to eq(pool) # rubocop:disable Rails/DynamicFindBy
    end

    it "finds a pool by name string (case-insensitive)" do
      pool = create(:pool, name: "find_by_name_pool")
      # NOTE: Pool.find_by_name is a custom method, not a dynamic finder
      expect(Pool.find_by_name("FIND_BY_NAME_POOL")).to eq(pool) # rubocop:disable Rails/DynamicFindBy
    end

    it "returns nil when no pool matches the name" do
      # NOTE: Pool.find_by_name is a custom method, not a dynamic finder
      expect(Pool.find_by_name("nonexistent_pool_xyz")).to be_nil # rubocop:disable Rails/DynamicFindBy
    end

    it "returns nil when name is blank" do
      # NOTE: Pool.find_by_name is a custom method, not a dynamic finder
      expect(Pool.find_by_name("")).to be_nil # rubocop:disable Rails/DynamicFindBy
    end

    it "returns nil when name is nil" do
      # NOTE: Pool.find_by_name is a custom method, not a dynamic finder
      expect(Pool.find_by_name(nil)).to be_nil # rubocop:disable Rails/DynamicFindBy
    end
  end
end
