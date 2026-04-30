# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Factory sanity checks                              #
# --------------------------------------------------------------------------- #

RSpec.describe IpBan do
  include_context "as admin"

  describe "factory" do
    it "produces a valid ip ban" do
      expect(create(:ip_ban)).to be_persisted
    end
  end
end
