# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ModAction Validations                               #
# --------------------------------------------------------------------------- #

RSpec.describe ModAction do
  include_context "as admin"

  describe "validations" do
    describe "creator referential integrity" do
      it "is invalid when creator_id references a non-existent user" do
        record = create(:mod_action)
        record.creator_id = -1
        expect(record).not_to be_valid
        expect(record.errors[:creator]).to include("must exist")
      end
    end
  end
end
