# frozen_string_literal: true

require "rails_helper"

RSpec.describe AutomodCheckJob do
  include_context "as admin"

  let(:comment) { create(:comment) }

  def perform(comment_id = comment.id)
    described_class.perform_now(comment_id)
  end

  describe "comment body checks" do
    it "creates a ticket when the comment body matches a for_comments rule" do
      rule = create(:automod_rule, :for_comments, regex: "badword", description: "spam description")
      comment.update_columns(body: "this contains badword")
      expect { perform }.to change(Ticket, :count).by(1)
      ticket = Ticket.last
      expect(ticket.qtype).to eq("comment")
      expect(ticket.disp_id).to eq(comment.id)
      expect(ticket.status).to eq("pending")
      expect(ticket.reason).to include(rule.name)
      expect(ticket.reason).to include(rule.description)
    end

    it "does not create a ticket when the comment body does not match any rule" do
      create(:automod_rule, :for_comments, regex: "badword")
      comment.update_columns(body: "totally clean content")
      expect { perform }.not_to change(Ticket, :count)
    end

    it "does not create a ticket when the only matching rule is not a for_comments rule" do
      create(:automod_rule, :for_usernames, regex: comment.body)
      expect { perform }.not_to change(Ticket, :count)
    end
  end

  describe "duplicate ticket prevention" do
    it "does not create a ticket when a pending ticket already exists for the comment" do
      create(:automod_rule, :for_comments, regex: "badword")
      comment.update_columns(body: "this contains badword")
      CurrentUser.as_system do
        Ticket.create!(
          creator_id: User.system.id,
          creator_ip_addr: "127.0.0.1",
          disp_id: comment.id,
          status: "pending",
          qtype: "comment",
          reason: "existing ticket",
        )
      end
      expect { perform }.not_to change(Ticket, :count)
    end

    it "does not create a ticket when a partial ticket already exists for the comment" do
      create(:automod_rule, :for_comments, regex: "badword")
      comment.update_columns(body: "this contains badword")
      CurrentUser.as_system do
        Ticket.create!(
          creator_id: User.system.id,
          creator_ip_addr: "127.0.0.1",
          disp_id: comment.id,
          status: "partial",
          qtype: "comment",
          reason: "existing ticket",
        )
      end
      expect { perform }.not_to change(Ticket, :count)
    end
  end

  describe "disabled rules" do
    it "does not create a ticket when the matching rule is disabled" do
      create(:disabled_automod_rule, :for_comments, regex: "badword")
      comment.update_columns(body: "this contains badword")
      expect { perform }.not_to change(Ticket, :count)
    end
  end

  describe "error handling" do
    it "handles a deleted comment gracefully" do
      comment_id = comment.id
      comment.destroy
      expect { perform(comment_id) }.not_to raise_error
    end
  end
end
