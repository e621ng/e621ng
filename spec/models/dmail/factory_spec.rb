# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Dmail Factory Sanity Checks                        #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  include_context "as admin"

  describe "factory" do
    it "produces a valid dmail with build" do
      expect(build(:dmail)).to be_valid
    end

    it "produces a valid dmail with create" do
      expect(create(:dmail)).to be_persisted
    end

    it "defaults is_read to false" do
      expect(create(:dmail).is_read).to be false
    end

    it "defaults is_deleted to false" do
      expect(create(:dmail).is_deleted).to be false
    end

    it "defaults owner to the recipient" do
      dmail = create(:dmail)
      expect(dmail.owner_id).to eq(dmail.to_id)
    end
  end
end
