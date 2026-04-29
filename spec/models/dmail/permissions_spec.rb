# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Dmail Permissions                                 #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  let(:sender)    { create(:user) }
  let(:recipient) { create(:user) }
  let(:other)     { create(:user) }
  let(:moderator) { create(:moderator_user) }
  let(:admin)     { create(:admin_user) }

  before do
    CurrentUser.user    = sender
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  def make_dmail(overrides = {})
    create(:dmail, from: sender, to: recipient, **overrides)
  end

  # ---------------------------------------------------------------------------
  # #visible_to?
  # ---------------------------------------------------------------------------
  describe "#visible_to?" do
    it "is visible to the owner" do
      dmail = make_dmail
      expect(dmail.visible_to?(recipient)).to be true
    end

    it "is not visible to an unrelated user" do
      dmail = make_dmail
      expect(dmail.visible_to?(other)).to be false
    end

    it "is not visible to the sender (sender's copy has a different owner)" do
      # The factory produces a recipient's copy — sender is not the owner
      dmail = make_dmail
      expect(dmail.visible_to?(sender)).to be false
    end

    # -------------------------------------------------------------------------
    # Moderator special access
    # -------------------------------------------------------------------------
    describe "moderator access" do
      it "is visible to a moderator when the dmail is from the system user" do
        dmail = create(:dmail, from: User.system, to: recipient, owner: recipient,
                               bypass_limits: true, no_email_notification: true)
        expect(dmail.visible_to?(moderator)).to be true
      end

      it "is not visible to a moderator for a regular user-to-user dmail they do not own" do
        dmail = make_dmail
        expect(dmail.visible_to?(moderator)).to be false
      end

      # FIXME: Come back to this after the Ticket factory gets made
      # it "is visible to a moderator when an associated dmail Ticket exists" do
      #   dmail = make_dmail
      #   # Create a ticket referencing this dmail, bypassing ticket validations
      #   ticket = Ticket.new(qtype: "dmail", disp_id: dmail.id,
      #                       reason: "Test report", accused_id: sender.id)
      #   ticket.creator_id = moderator.id
      #   ticket.save!(validate: false)
      #
      #   expect(dmail.visible_to?(moderator)).to be true
      # end
    end

    # -------------------------------------------------------------------------
    # Admin special access
    # -------------------------------------------------------------------------
    describe "admin access" do
      it "is visible to an admin when the recipient is an admin" do
        admin_recipient = create(:admin_user)
        dmail = create(:dmail, from: sender, to: admin_recipient, owner: admin_recipient,
                               no_email_notification: true)
        expect(dmail.visible_to?(admin)).to be true
      end

      it "is visible to an admin when the sender is an admin" do
        admin_sender = create(:admin_user)
        CurrentUser.user = admin_sender
        dmail = create(:dmail, from: admin_sender, to: recipient, owner: recipient,
                               no_email_notification: true)
        expect(dmail.visible_to?(admin)).to be true
      end

      it "is not visible to an admin for a regular user-to-user dmail they do not own" do
        dmail = make_dmail
        expect(dmail.visible_to?(admin)).to be false
      end
    end
  end
end
