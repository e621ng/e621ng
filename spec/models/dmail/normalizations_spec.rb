# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Dmail Normalizations                              #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # body — \r\n → \n
  # ---------------------------------------------------------------------------
  describe "body normalization" do
    it "converts \\r\\n line endings to \\n on create" do
      dmail = create(:dmail, body: "line one\r\nline two")
      expect(dmail.body).to eq("line one\nline two")
    end

    it "converts \\r\\n line endings to \\n on update" do
      dmail = create(:dmail, body: "initial")
      dmail.update!(body: "updated\r\nbody")
      expect(dmail.body).to eq("updated\nbody")
    end

    it "leaves \\n-only bodies unchanged" do
      dmail = create(:dmail, body: "line one\nline two")
      expect(dmail.body).to eq("line one\nline two")
    end
  end
end
