# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          StaffFile Factory                                  #
# --------------------------------------------------------------------------- #

RSpec.describe StaffFile do
  include_context "as admin"

  describe "factory" do
    it "produces a valid staff_file with build" do
      staff_file = build(:staff_file)
      expect(staff_file).to be_valid, staff_file.errors.full_messages.join(", ")
    end

    it "produces a persisted staff_file with create" do
      staff_file = create(:staff_file)
      expect(staff_file).to be_persisted
    end
  end
end
