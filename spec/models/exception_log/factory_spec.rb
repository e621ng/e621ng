# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ExceptionLog Factory                                  #
# --------------------------------------------------------------------------- #

RSpec.describe ExceptionLog do
  include_context "as admin"

  describe "factory" do
    it "produces a valid record with build" do
      record = build(:exception_log)
      expect(record).to be_valid, record.errors.full_messages.join(", ")
    end

    it "produces a persisted record with create" do
      expect(create(:exception_log)).to be_persisted
    end
  end
end
