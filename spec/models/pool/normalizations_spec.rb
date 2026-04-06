# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Pool Normalizations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # normalize_name (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_name" do
    it "collapses consecutive spaces into a single underscore" do
      pool = create(:pool, name: "my  pool")
      expect(pool.name).to eq("my_pool")
    end

    it "collapses consecutive underscores into a single underscore" do
      pool = create(:pool, name: "my__pool")
      expect(pool.name).to eq("my_pool")
    end

    it "collapses mixed spaces and underscores into a single underscore" do
      pool = create(:pool, name: "my _pool")
      expect(pool.name).to eq("my_pool")
    end

    it "strips a leading underscore" do
      pool = create(:pool, name: "_leading")
      expect(pool.name).to eq("leading")
    end

    it "strips a trailing underscore" do
      pool = create(:pool, name: "trailing_")
      expect(pool.name).to eq("trailing")
    end

    it "leaves an already-normalized name unchanged" do
      pool = create(:pool, name: "already_normal")
      expect(pool.name).to eq("already_normal")
    end
  end

  # -------------------------------------------------------------------------
  # normalize_post_ids (before_validation)
  # -------------------------------------------------------------------------
  describe "normalize_post_ids" do
    it "deduplicates post_ids, keeping only unique values" do
      pool = create(:pool, post_ids: [1, 2, 2, 3, 1], skip_sync: true)
      expect(pool.post_ids).to eq([1, 2, 3])
    end

    it "preserves a list that is already unique" do
      pool = create(:pool, post_ids: [10, 20, 30], skip_sync: true)
      expect(pool.post_ids).to eq([10, 20, 30])
    end
  end

  # -------------------------------------------------------------------------
  # description normalizer (\r\n → \n)
  # -------------------------------------------------------------------------
  describe "description normalization" do
    it "converts \\r\\n line endings to \\n" do
      pool = create(:pool, description: "line one\r\nline two")
      expect(pool.description).to eq("line one\nline two")
    end

    it "leaves \\n-only line endings unchanged" do
      pool = create(:pool, description: "line one\nline two")
      expect(pool.description).to eq("line one\nline two")
    end
  end
end
