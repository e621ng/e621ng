# frozen_string_literal: true

# This model does not exist in this fork.
return if true # rubocop:disable Lint/LiteralAsCondition

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Blip Normalizations                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Blip do
  include_context "as member"

  # -------------------------------------------------------------------------
  # body — \r\n → \n
  # -------------------------------------------------------------------------
  describe "body — normalization" do
    it "converts \\r\\n line endings to \\n in the body" do
      blip = create(:blip, body: "line one\r\nline two\r\nline three")
      expect(blip.body).to eq("line one\nline two\nline three")
    end

    it "leaves \\n-only line endings unchanged" do
      blip = create(:blip, body: "line one\nline two")
      expect(blip.body).to eq("line one\nline two")
    end

    it "applies normalization on update as well" do
      blip = create(:blip, body: "initial body text")
      blip.update!(body: "updated\r\nbody text")
      expect(blip.body).to eq("updated\nbody text")
    end
  end
end
