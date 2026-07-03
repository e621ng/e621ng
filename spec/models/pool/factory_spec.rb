# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                              Pool Factory                                   #
# --------------------------------------------------------------------------- #

RSpec.describe Pool do
  include_context "as admin"

  describe "factory" do
    it "produces a valid pool with build" do
      pool = build(:pool)
      expect(pool).to be_valid, pool.errors.full_messages.join(", ")
    end

    it "produces a valid pool with create" do
      pool = create(:pool)
      expect(pool).to be_persisted
    end

    it "produces a valid series pool" do
      pool = create(:series_pool)
      expect(pool).to be_persisted
      expect(pool.category).to eq("series")
    end

    it "produces a valid collection pool" do
      pool = create(:collection_pool)
      expect(pool).to be_persisted
      expect(pool.category).to eq("collection")
    end
  end
end
