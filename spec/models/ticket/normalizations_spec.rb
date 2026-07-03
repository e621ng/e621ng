# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  describe "reason normalization" do
    it "converts \\r\\n line endings to \\n on create" do
      ticket = create(:ticket, reason: "line one\r\nline two")
      expect(ticket.reason).to eq("line one\nline two")
    end

    it "converts \\r\\n line endings to \\n on update" do
      ticket = create(:ticket)
      ticket.update_columns(response: "existing response")
      ticket.update!(reason: "updated\r\nbody")
      expect(ticket.reason).to eq("updated\nbody")
    end
  end
end
