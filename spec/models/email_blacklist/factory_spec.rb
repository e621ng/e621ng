# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        EmailBlacklist Factory                               #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  describe "factory" do
    it "produces a valid record with build" do
      expect(build(:email_blacklist)).to be_valid
    end

    it "produces a persisted record with create" do
      expect(create(:email_blacklist)).to be_persisted
    end
  end
end
