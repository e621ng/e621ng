# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                     PostSetMaintainer Factory                               #
# --------------------------------------------------------------------------- #

RSpec.describe PostSetMaintainer do
  include_context "as member"

  describe "factory" do
    it "produces a valid pending record with create" do
      m = create(:post_set_maintainer)
      expect(m).to be_persisted
      expect(m.status).to eq("pending")
    end

    it "produces a valid approved record" do
      m = create(:approved_post_set_maintainer)
      expect(m).to be_persisted
      expect(m.status).to eq("approved")
    end

    it "produces a valid blocked record" do
      m = create(:blocked_post_set_maintainer)
      expect(m).to be_persisted
      expect(m.status).to eq("blocked")
    end
  end
end
