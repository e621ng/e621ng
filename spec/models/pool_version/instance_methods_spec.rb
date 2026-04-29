# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                      PoolVersion Instance Methods                           #
# --------------------------------------------------------------------------- #

RSpec.describe PoolVersion do
  include_context "as admin"

  # -------------------------------------------------------------------------
  # #previous
  # -------------------------------------------------------------------------
  describe "#previous" do
    it "returns nil for the first version of a pool" do
      pool = create(:pool)
      version1 = pool.versions.first
      expect(version1.previous).to be_nil
    end

    it "returns the immediately preceding version" do
      pool = create(:pool)
      pool.update!(description: "second version")
      versions = pool.versions.order(:version)
      expect(versions.last.previous).to eq(versions.first)
    end

    it "returns the highest prior version when multiple versions exist" do
      pool = create(:pool)
      pool.update!(description: "v2")
      pool.update!(description: "v3")
      versions = pool.versions.order(:version)
      # version 3's previous should be version 2, not version 1
      expect(versions.last.previous).to eq(versions.second)
    end
  end

  # -------------------------------------------------------------------------
  # #pretty_name
  # -------------------------------------------------------------------------
  describe "#pretty_name" do
    it "replaces underscores with spaces" do
      pool = create(:pool, name: "my_pool_name")
      pv = pool.versions.first
      expect(pv.pretty_name).to eq("my pool name")
    end

    it "returns a name with no underscores unchanged" do
      pool = create(:pool, name: "simplepool_#{SecureRandom.hex(4)}")
      pv = pool.versions.first
      # Strip the hex suffix underscores for a clean assertion
      expect(pv.pretty_name).to eq(pv.name.tr("_", " "))
    end

    it "returns '(Unknown Name)' when name is nil" do
      pv = PoolVersion.new(name: nil)
      expect(pv.pretty_name).to eq("(Unknown Name)")
    end
  end

  # -------------------------------------------------------------------------
  # #updater_name
  # -------------------------------------------------------------------------
  describe "#updater_name" do
    it "returns the name of the updater user" do
      pool = create(:pool)
      pv = pool.versions.first
      expect(pv.updater_name).to eq(CurrentUser.user.name)
    end
  end
end
