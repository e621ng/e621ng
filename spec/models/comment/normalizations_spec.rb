# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       Comment Normalizations                                #
# --------------------------------------------------------------------------- #

RSpec.describe Comment do
  include_context "as member"

  # -------------------------------------------------------------------------
  # body — \r\n → \n
  # -------------------------------------------------------------------------
  describe "body normalization" do
    it "converts \\r\\n line endings to \\n on create" do
      comment = create(:comment, body: "line one\r\nline two")
      expect(comment.body).to eq("line one\nline two")
    end

    it "converts \\r\\n line endings to \\n on update" do
      comment = create(:comment, body: "initial body")
      comment.update!(body: "updated\r\nbody")
      expect(comment.body).to eq("updated\nbody")
    end

    it "leaves \\n line endings unchanged" do
      comment = create(:comment, body: "line one\nline two")
      expect(comment.body).to eq("line one\nline two")
    end
  end
end
