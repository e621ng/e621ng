# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  # -------------------------------------------------------------------------
  # reason: CRLF → LF normalization
  # -------------------------------------------------------------------------
  describe "reason normalization" do
    it "converts CRLF line endings to LF" do
      appeal = create(:appeal, reason: "line one\r\nline two")
      expect(appeal.reason).to eq("line one\nline two")
    end

    it "leaves LF-only reasons unchanged" do
      appeal = create(:appeal, reason: "line one\nline two")
      expect(appeal.reason).to eq("line one\nline two")
    end
  end
end
