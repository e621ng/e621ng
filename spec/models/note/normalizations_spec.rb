# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Note Normalizations                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Note do
  include_context "as member"

  # -------------------------------------------------------------------------
  # body — \r\n → \n
  # -------------------------------------------------------------------------
  describe "body normalization — \\r\\n → \\n" do
    it "converts \\r\\n to \\n on create" do
      note = create(:note, body: "line one\r\nline two")
      expect(note.body).to eq("line one\nline two")
    end

    it "converts \\r\\n to \\n on update" do
      note = create(:note, body: "initial")
      note.update!(body: "updated\r\nbody")
      expect(note.body).to eq("updated\nbody")
    end

    it "leaves bare \\n unchanged" do
      note = create(:note, body: "line one\nline two")
      expect(note.body).to eq("line one\nline two")
    end

    it "leaves a body with no line endings unchanged" do
      note = create(:note, body: "single line")
      expect(note.body).to eq("single line")
    end

    it "handles multiple \\r\\n sequences in one body" do
      note = create(:note, body: "a\r\nb\r\nc")
      expect(note.body).to eq("a\nb\nc")
    end
  end
end
