# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         PostApproval Factory                                #
# --------------------------------------------------------------------------- #

RSpec.describe PostApproval do
  include_context "as member"

  describe "factory" do
    it "produces a valid record with build" do
      record = build(:post_approval)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      expect(create(:post_approval)).to be_persisted
    end
  end
end
