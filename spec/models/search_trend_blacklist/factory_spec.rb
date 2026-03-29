# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    SearchTrendBlacklist Factory                              #
# --------------------------------------------------------------------------- #

RSpec.describe SearchTrendBlacklist do
  include_context "as admin"

  describe "factory" do
    it "produces a valid record with build" do
      record = build(:search_trend_blacklist)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      record = create(:search_trend_blacklist)
      expect(record).to be_persisted
    end
  end
end
