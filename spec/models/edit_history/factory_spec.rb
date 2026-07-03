# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         EditHistory Factory                                 #
# --------------------------------------------------------------------------- #

RSpec.describe EditHistory do
  include_context "as member"

  describe "factory" do
    it "produces a valid record with build" do
      record = build(:edit_history)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      record = create(:edit_history)
      expect(record).to be_persisted
    end
  end
end
