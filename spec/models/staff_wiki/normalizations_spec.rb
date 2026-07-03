# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       StaffWiki Normalizations                              #
# --------------------------------------------------------------------------- #

RSpec.describe StaffWiki do
  include_context "as member"

  # -------------------------------------------------------------------------
  # body — \r\n → \n
  # -------------------------------------------------------------------------
  describe "body — normalization" do
    it "converts \\r\\n line endings to \\n in the body on create" do
      wiki = create(:staff_wiki, body: "line one\r\nline two\r\nline three")
      expect(wiki.body).to eq("line one\nline two\nline three")
    end

    it "leaves \\n-only line endings unchanged" do
      wiki = create(:staff_wiki, body: "line one\nline two")
      expect(wiki.body).to eq("line one\nline two")
    end

    it "applies normalization on update as well" do
      wiki = create(:staff_wiki, body: "initial body text")
      wiki.update!(body: "updated\r\nbody text")
      expect(wiki.body).to eq("updated\nbody text")
    end
  end
end
