# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Upload Factory Checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe Upload do
  describe "factory" do
    it "produces a valid persisted upload" do
      expect(create(:upload)).to be_persisted
    end
  end
end
