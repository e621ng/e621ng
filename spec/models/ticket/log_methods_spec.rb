# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  let(:creator)   { create(:user) }
  let(:moderator) { create(:moderator_user) }

  before do
    CurrentUser.user    = creator
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_ticket
    create(:ticket).tap { |t| t.update_columns(response: "initial response") }
  end

  # -------------------------------------------------------------------------
  # #log_update
  # -------------------------------------------------------------------------
  describe "#log_update" do
    it "logs a ticket_update ModAction when status changes" do
      ticket = make_ticket
      expect { ticket.update!(status: "approved", response: "Resolved.", handler: moderator) }
        .to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("ticket_update")
    end

    it "logs a ticket_update ModAction when response changes" do
      ticket = make_ticket
      expect { ticket.update!(response: "New response text.", handler: moderator) }
        .to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("ticket_update")
    end

    it "does not log when neither status nor response changes" do
      ticket = make_ticket
      expect { ticket.update!(reason: "Updated reason.") }
        .not_to change(ModAction, :count)
    end

    it "stores previous status and response in the log values" do
      ticket = make_ticket
      ticket.update!(response: "Initial.", handler: moderator)
      ModAction.delete_all
      ticket.update!(status: "approved", handler: moderator)
      log = ModAction.last
      expect(log[:values]).to include("ticket_id" => ticket.id, "status" => "approved")
    end
  end

  # -------------------------------------------------------------------------
  # #claim! / #unclaim!
  # -------------------------------------------------------------------------
  describe "#claim!" do
    it "sets claimant_id to the given user" do
      ticket = make_ticket
      ticket.claim!(moderator)
      expect(ticket.reload.claimant_id).to eq(moderator.id)
    end

    it "logs a ticket_claim ModAction" do
      ticket = make_ticket
      expect { ticket.claim!(moderator) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("ticket_claim")
      expect(ModAction.last[:values]).to include("ticket_id" => ticket.id)
    end
  end

  describe "#unclaim!" do
    it "clears claimant_id" do
      ticket = make_ticket
      ticket.update_columns(claimant_id: moderator.id)
      ticket.unclaim!(moderator)
      expect(ticket.reload.claimant_id).to be_nil
    end

    it "logs a ticket_unclaim ModAction" do
      ticket = make_ticket
      ticket.update_columns(claimant_id: moderator.id)
      expect { ticket.unclaim!(moderator) }.to change(ModAction, :count).by(1)
      expect(ModAction.last.action).to eq("ticket_unclaim")
      expect(ModAction.last[:values]).to include("ticket_id" => ticket.id)
    end
  end

  # -------------------------------------------------------------------------
  # #create_dmail
  # -------------------------------------------------------------------------
  describe "#create_dmail" do
    it "sends a dmail to the creator when status changes" do
      ticket = make_ticket
      ticket.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      expect { ticket.update!(status: "approved") }.to change(Dmail, :count).by(2)
    end

    it "sends a dmail when send_update_dmail is set and response changes" do
      ticket = make_ticket
      ticket.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      ticket.send_update_dmail = "1"
      expect { ticket.update!(response: "Updated response text.") }.to change(Dmail, :count).by(2)
    end

    it "does not send a dmail when neither status nor response changes with send_update_dmail" do
      ticket = make_ticket
      ticket.update_columns(handler_id: moderator.id)
      CurrentUser.user = moderator
      expect { ticket.update!(reason: "Updated reason text.") }.not_to change(Dmail, :count)
    end

    it "does not send a dmail when the creator is the system user" do
      CurrentUser.user = User.system
      ticket = build(:ticket, accused_user: create(:user))
      ticket.creator_id      = CurrentUser.id
      ticket.creator_ip_addr = CurrentUser.ip_addr
      ticket.save!(validate: false)
      ticket.update_columns(handler_id: moderator.id, response: "initial response")
      CurrentUser.user = moderator
      expect { ticket.update!(status: "approved") }.not_to change(Dmail, :count)
    end
  end
end
