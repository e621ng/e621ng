# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          AvoidPosting Scopes                                #
# --------------------------------------------------------------------------- #

RSpec.describe AvoidPosting do
  include_context "as admin"

  let!(:active_dnp)   { create(:avoid_posting) }
  let!(:inactive_dnp) { create(:inactive_avoid_posting) }

  describe ".active" do
    it "includes active entries" do
      expect(AvoidPosting.active).to include(active_dnp)
    end

    it "excludes deleted entries" do
      expect(AvoidPosting.active).not_to include(inactive_dnp)
    end
  end

  describe ".deleted" do
    it "includes deleted entries" do
      expect(AvoidPosting.deleted).to include(inactive_dnp)
    end

    it "excludes active entries" do
      expect(AvoidPosting.deleted).not_to include(active_dnp)
    end
  end
end
