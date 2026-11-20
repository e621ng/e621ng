# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ticket do
  include_context "as member"

  # -------------------------------------------------------------------------
  # #open_from_same_user
  # -------------------------------------------------------------------------
  describe "#open_from_same_user" do
    let(:moderator) { create(:moderator_user) }
    let(:janitor)   { create(:janitor_user) }

    it "returns the creator's other pending and partial tickets" do
      ticket = create(:ticket)
      pending = create(:ticket)
      partial = create(:ticket)
      partial.update_columns(status: "partial")

      expect(ticket.open_from_same_user(moderator)).to contain_exactly(pending, partial)
    end

    it "excludes the ticket itself" do
      ticket = create(:ticket)
      expect(ticket.open_from_same_user(moderator)).not_to include(ticket)
    end

    it "excludes approved tickets" do
      ticket = create(:ticket)
      approved = create(:ticket)
      approved.update_columns(status: "approved")

      expect(ticket.open_from_same_user(moderator)).not_to include(approved)
    end

    it "excludes tickets from other creators" do
      ticket = create(:ticket)
      other = CurrentUser.scoped(create(:user)) { create(:ticket) }

      expect(ticket.open_from_same_user(moderator)).not_to include(other)
    end

    it "excludes tickets the viewer cannot see" do
      ticket = create(:ticket, :pool_type)
      user_ticket = create(:ticket)
      pool_ticket = create(:ticket, :pool_type)

      expect(ticket.open_from_same_user(janitor)).to contain_exactly(pool_ticket)
      expect(ticket.open_from_same_user(moderator)).to contain_exactly(user_ticket, pool_ticket)
    end
  end

  # -------------------------------------------------------------------------
  # #all_for_same_content
  # -------------------------------------------------------------------------
  describe "#all_for_same_content" do
    let(:moderator) { create(:moderator_user) }
    let(:janitor)   { create(:janitor_user) }

    it "returns other tickets for the same content regardless of status or creator" do
      accused = create(:user)
      ticket = create(:ticket, accused_user: accused)
      approved = create(:ticket, accused_user: accused)
      approved.update_columns(status: "approved")
      other_creator = CurrentUser.scoped(create(:user)) { create(:ticket, accused_user: accused) }

      expect(ticket.all_for_same_content(moderator)).to contain_exactly(approved, other_creator)
    end

    it "excludes the ticket itself" do
      ticket = create(:ticket)
      expect(ticket.all_for_same_content(moderator)).not_to include(ticket)
    end

    it "excludes tickets for different content" do
      ticket = create(:ticket)
      other = create(:ticket, accused_user: create(:user))

      expect(ticket.all_for_same_content(moderator)).not_to include(other)
    end

    it "excludes tickets the viewer cannot see" do
      accused = create(:user)
      ticket = create(:ticket, accused_user: accused)
      CurrentUser.scoped(create(:user)) { create(:ticket, accused_user: accused) }

      expect(ticket.all_for_same_content(janitor)).to be_empty
    end
  end

  # -------------------------------------------------------------------------
  # #warnable?
  # -------------------------------------------------------------------------
  describe "#warnable?" do
    it "returns true for a pending blip ticket whose blip has not been warned" do
      ticket = create(:ticket, :blip_type)
      expect(ticket.warnable?).to be true
    end

    it "returns false when the blip has already been warned" do
      ticket = create(:ticket, :blip_type)
      ticket.content.update_columns(warning_type: "warning")
      expect(ticket.warnable?).to be false
    end

    it "returns false when the ticket is not pending" do
      ticket = create(:ticket, :blip_type)
      ticket.update_columns(status: "approved")
      expect(ticket.warnable?).to be false
    end

    it "returns false for a ticket whose content does not support warnings (e.g. pool)" do
      ticket = create(:ticket, :pool_type)
      expect(ticket.warnable?).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #subject
  # -------------------------------------------------------------------------
  describe "#subject" do
    it "returns the reason as-is when it is 40 characters or fewer" do
      ticket = create(:ticket, reason: "Short reason.")
      expect(ticket.subject).to eq("Short reason.")
    end

    it "truncates the reason to 38 chars with ellipsis when longer than 40 characters" do
      ticket = create(:ticket, reason: "a" * 45)
      expect(ticket.subject).to eq("#{'a' * 38}...")
    end

    it "trims leading newlines from the reason" do
      ticket = create(:ticket, reason: "\n\nReason with leading newlines.")
      expect(ticket.subject).to eq("Reason with leading newlines.")
    end

    it "returns the first line of the reason for post-type tickets" do
      reason = "First line\nSecond line"
      ticket = create(:ticket, :post_type, reason: reason)
      expect(ticket.subject).to eq("First line")
    end

    it "trims leading newlines for post-type tickets" do
      reason = "\n\nFirst line\nSecond line"
      ticket = create(:ticket, :post_type, reason: reason)
      expect(ticket.subject).to eq("First line")
    end

    it "returns the first line of the reason for replacement-type tickets" do
      reason = "First line\nSecond line"
      ticket = create(:ticket, :replacement_type, reason: reason)
      expect(ticket.subject).to eq("First line")
    end

    it "trims leading newlines for replacement-type tickets" do
      reason = "\n\nFirst line\nSecond line"
      ticket = create(:ticket, :replacement_type, reason: reason)
      expect(ticket.subject).to eq("First line")
    end
  end

  # -------------------------------------------------------------------------
  # #type_title
  # -------------------------------------------------------------------------
  describe "#type_title" do
    it "returns '<Model Name>' for user tickets" do
      ticket = create(:ticket)
      expect(ticket.type_title).to eq("User")
    end

    it "returns 'Post' for post tickets" do
      ticket = create(:ticket, :post_type)
      expect(ticket.type_title).to eq("Post")
    end

    it "returns 'Wiki Page' for wiki tickets" do
      ticket = create(:ticket, :wiki_type)
      expect(ticket.type_title).to eq("Wiki Page")
    end
  end

  # -------------------------------------------------------------------------
  # #content / #content=
  # -------------------------------------------------------------------------
  describe "#content" do
    it "returns the associated content record" do
      accused = create(:user)
      ticket = create(:ticket, accused_user: accused)
      expect(ticket.content).to eq(accused)
    end

    it "returns nil when disp_id does not match any record" do
      ticket = build(:ticket)
      ticket.disp_id = 0
      expect(ticket.content).to be_nil
    end

    it "memoizes the result" do
      ticket = create(:ticket)
      first_call = ticket.content
      second_call = ticket.content
      expect(first_call).to equal(second_call)
    end
  end

  describe "#content=" do
    it "sets disp_id from the given content object" do
      ticket = build(:ticket)
      accused = create(:user)
      ticket.content = accused
      expect(ticket.disp_id).to eq(accused.id)
    end

    it "sets disp_id to nil when assigned nil" do
      ticket = build(:ticket)
      ticket.content = nil
      expect(ticket.disp_id).to be_nil
    end
  end
end
