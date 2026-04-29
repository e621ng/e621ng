# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  # -------------------------------------------------------------------------
  # qtype param
  # -------------------------------------------------------------------------
  describe ".search qtype param" do
    let!(:user_ticket) { create(:ticket) }
    let!(:wiki_ticket) { create(:ticket, :wiki_type, accused_user: create(:user)) }

    it "filters by qtype" do
      expect(Ticket.search(qtype: "user")).to include(user_ticket)
      expect(Ticket.search(qtype: "user")).not_to include(wiki_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # status param
  # -------------------------------------------------------------------------
  describe ".search status param" do
    let!(:pending_ticket)  { create(:ticket) }
    let!(:partial_ticket)  { create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(status: "partial") } }
    let!(:approved_ticket) { create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(status: "approved") } }

    it "filters pending tickets" do
      result = Ticket.search(status: "pending")
      expect(result).to include(pending_ticket)
      expect(result).not_to include(partial_ticket, approved_ticket)
    end

    it "filters partial tickets" do
      result = Ticket.search(status: "partial")
      expect(result).to include(partial_ticket)
      expect(result).not_to include(pending_ticket, approved_ticket)
    end

    it "filters approved tickets" do
      result = Ticket.search(status: "approved")
      expect(result).to include(approved_ticket)
      expect(result).not_to include(pending_ticket, partial_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # status: pending_claimed / pending_unclaimed
  # -------------------------------------------------------------------------
  describe ".search status: pending_claimed / pending_unclaimed" do
    let(:claimant) { create(:moderator_user) }
    let!(:unclaimed) { create(:ticket) }
    let!(:claimed) do
      create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(claimant_id: claimant.id) }
    end

    it "pending_claimed returns only pending tickets with a claimant" do
      result = Ticket.search(status: "pending_claimed")
      expect(result).to include(claimed)
      expect(result).not_to include(unclaimed)
    end

    it "pending_unclaimed returns only pending tickets without a claimant" do
      result = Ticket.search(status: "pending_unclaimed")
      expect(result).to include(unclaimed)
      expect(result).not_to include(claimed)
    end
  end

  # -------------------------------------------------------------------------
  # disp_id param
  # -------------------------------------------------------------------------
  describe ".search disp_id param" do
    let(:accused_a) { create(:user) }
    let(:accused_b) { create(:user) }
    let!(:ticket_a) { create(:ticket, accused_user: accused_a) }
    let!(:ticket_b) { create(:ticket, accused_user: accused_b) }

    it "filters by disp_id" do
      result = Ticket.search(disp_id: ticket_a.disp_id.to_s)
      expect(result).to include(ticket_a)
      expect(result).not_to include(ticket_b)
    end
  end

  # -------------------------------------------------------------------------
  # default ordering
  # -------------------------------------------------------------------------
  describe ".search default order" do
    let!(:approved) { create(:ticket).tap { |t| t.update_columns(status: "approved") } }
    let!(:partial)  { create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(status: "partial") } }
    let!(:pending)  { create(:ticket, accused_user: create(:user)) }

    it "orders pending before partial before approved" do
      ids = Ticket.search({}).ids
      expect(ids.index(pending.id)).to be < ids.index(partial.id)
      expect(ids.index(partial.id)).to be < ids.index(approved.id)
    end

    it "orders newer pending tickets before older pending tickets" do
      older = create(:ticket, accused_user: create(:user))
      older.update_columns(created_at: 1.hour.ago)
      newer = create(:ticket, accused_user: create(:user))

      ids = Ticket.search({}).ids
      expect(ids.index(newer.id)).to be < ids.index(older.id)
    end
  end
end
