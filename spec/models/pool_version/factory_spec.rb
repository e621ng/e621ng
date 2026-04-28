# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          PoolVersion Factory                                #
# --------------------------------------------------------------------------- #

RSpec.describe PoolVersion do
  include_context "as admin"

  describe "factory" do
    it "produces a valid pool_version with create" do
      pv = create(:pool_version)
      expect(pv).to be_persisted
    end

    it "associates to a real pool" do
      pv = create(:pool_version)
      expect { pv.pool }.not_to raise_error
    end

    it "associates to a real updater" do
      pv = create(:pool_version)
      expect { pv.updater }.not_to raise_error
    end
  end
end
