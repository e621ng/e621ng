# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  let(:other_member) { create(:user) }
  let(:janitor)      { create(:janitor_user) }
  let(:moderator)    { create(:moderator_user) }

  # -------------------------------------------------------------------------
  # .active
  # -------------------------------------------------------------------------
  describe ".active" do
    let!(:pending_ticket)  { create(:ticket) }
    let!(:partial_ticket)  { create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(status: "partial") } }
    let!(:approved_ticket) { create(:ticket, accused_user: create(:user)).tap { |t| t.update_columns(status: "approved") } }

    it "includes pending tickets" do
      expect(Ticket.active).to include(pending_ticket)
    end

    it "includes partial tickets" do
      expect(Ticket.active).to include(partial_ticket)
    end

    it "excludes approved tickets" do
      expect(Ticket.active).not_to include(approved_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # .for_creator
  # -------------------------------------------------------------------------
  describe ".for_creator" do
    let(:creator) { CurrentUser.user }
    let!(:own_ticket) { create(:ticket) }
    let!(:other_ticket) do
      CurrentUser.user = other_member
      t = create(:ticket, accused_user: create(:user))
      CurrentUser.user = creator
      t
    end

    it "returns tickets created by the given user" do
      expect(Ticket.for_creator(own_ticket.creator_id)).to include(own_ticket)
    end

    it "excludes tickets from other creators" do
      expect(Ticket.for_creator(own_ticket.creator_id)).not_to include(other_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # .for_accused
  # -------------------------------------------------------------------------
  describe ".for_accused" do
    let(:accused)       { create(:user) }
    let!(:own_ticket)   { create(:ticket, accused_user: accused) }
    let!(:other_ticket) { create(:ticket, accused_user: create(:user)) }

    it "returns tickets for the given accused user" do
      expect(Ticket.for_accused(accused.id)).to include(own_ticket)
    end

    it "excludes tickets for other accused users" do
      expect(Ticket.for_accused(accused.id)).not_to include(other_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # .visible
  # -------------------------------------------------------------------------
  describe ".visible" do
    let(:creator) { CurrentUser.user }

    let!(:user_ticket) do
      create(:ticket)
    end

    let!(:pool_ticket) do
      create(:ticket, :pool_type, accused_user: create(:user))
    end

    let!(:dmail_ticket) do
      dmail = create(:dmail, to: creator)
      t = build(:ticket, :dmail_type, dmail: dmail)
      t.creator_id      = CurrentUser.id
      t.creator_ip_addr = CurrentUser.ip_addr
      t.save!(validate: false)
      t
    end

    let!(:other_user_ticket) do
      CurrentUser.user = other_member
      t = create(:ticket, accused_user: create(:user))
      CurrentUser.user = creator
      t
    end

    let!(:other_dmail_ticket) do
      CurrentUser.user = other_member
      dmail = create(:dmail, to: other_member)
      t = build(:ticket, :dmail_type, dmail: dmail)
      t.creator_id      = CurrentUser.id
      t.creator_ip_addr = CurrentUser.ip_addr
      t.save!(validate: false)
      CurrentUser.user = creator
      t
    end

    context "moderator" do
      it "sees all tickets regardless of type" do
        result = Ticket.visible(moderator)
        expect(result).to include(user_ticket, pool_ticket, dmail_ticket, other_user_ticket, other_dmail_ticket)
      end
    end

    context "janitor" do
      let!(:janitor_user_ticket) do
        CurrentUser.user = janitor
        t = create(:ticket, accused_user: create(:user))
        CurrentUser.user = creator
        t
      end

      it "sees their own tickets even when they are user-type" do
        result = Ticket.visible(janitor)
        expect(result).to include(janitor_user_ticket)
      end

      it "sees non-dmail, non-user tickets created by others" do
        result = Ticket.visible(janitor)
        expect(result).to include(pool_ticket)
      end

      it "does not see user-type tickets created by others" do
        result = Ticket.visible(janitor)
        expect(result).not_to include(other_user_ticket)
      end

      it "does not see dmail-type tickets created by others" do
        result = Ticket.visible(janitor)
        expect(result).not_to include(other_dmail_ticket)
      end
    end

    context "regular member" do
      it "sees only their own tickets" do
        result = Ticket.visible(creator)
        expect(result).to include(user_ticket, pool_ticket, dmail_ticket)
        expect(result).not_to include(other_user_ticket, other_dmail_ticket)
      end
    end
  end
end
