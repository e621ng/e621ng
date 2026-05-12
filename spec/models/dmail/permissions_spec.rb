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
  let(:dmail)     { create(:dmail, from: sender, to: recipient) }

  before do
    CurrentUser.user    = sender
    CurrentUser.ip_addr = "127.0.0.1"
  end

  after do
    CurrentUser.user    = nil
    CurrentUser.ip_addr = nil
  end

  # ---------------------------------------------------------------------------
  # #visible_to?
  # ---------------------------------------------------------------------------
  describe "#visible_to?" do
    it "is visible to the owner" do
      expect(dmail.visible_to?(recipient)).to be true
    end

    it "is not visible to an unrelated user" do
      expect(dmail.visible_to?(other)).to be false
    end

    it "is not visible to the sender (sender's copy has a different owner)" do
      # The factory produces a recipient's copy — sender is not the owner
      expect(dmail.visible_to?(sender)).to be false
    end

    # -------------------------------------------------------------------------
    # Keyed access
    # -------------------------------------------------------------------------
    describe "Keyed access" do
      let(:janitor) { create(:janitor_user) }

      it "is visible to any staff member with the right key when the dmail is from a staff member" do
        dmail = create(:dmail, from: moderator, to: recipient, owner: recipient)
        expect(dmail.visible_to?(janitor, dmail.generate_key)).to be true
      end

      it "is visible to any staff member with the right key when the dmail is to a staff member" do
        dmail = create(:dmail, from: sender, to: moderator, owner: moderator)
        expect(dmail.visible_to?(janitor, dmail.generate_key)).to be true
      end

      it "is not visible to staff members with the wrong key" do
        dmail = create(:dmail, from: sender, to: moderator, owner: moderator)
        expect(dmail.visible_to?(janitor, "v1:YouGetNothing!GoodDaySir!")).to be false
      end

      it "is not visible to staff members with the right key when the dmail isn't from or to a staff member" do
        expect(dmail.visible_to?(janitor, dmail.generate_key)).to be false
      end

      it "is not visible to non-staff members with the right key" do
        dmail = create(:dmail, from: janitor, to: moderator, owner: moderator)
        expect(dmail.visible_to?(other, dmail.generate_key)).to be false
      end
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
        expect(dmail.visible_to?(moderator)).to be false
      end

      it "is only visible to a moderator when an associated dmail Ticket exists" do
        # TODO: After the Ticket factory gets made, use factory instead
        Ticket.create(
          qtype: "dmail",
          disp_id: dmail.id,
          reason: "Test report",
          accused_id: sender.id,
          creator_id: recipient.id,
          creator_ip_addr: "127.0.0.1",
        )

        expect(dmail.visible_to?(moderator)).to be true
      end
    end

    # -------------------------------------------------------------------------
    # Admin special access
    # -------------------------------------------------------------------------
    describe "admin access" do
      it "is visible to any admin when the recipient is an admin" do
        admin_recipient = create(:admin_user)
        dmail = create(:dmail, from: sender, to: admin_recipient, owner: admin_recipient,
                               no_email_notification: true)
        expect(dmail.visible_to?(admin)).to be true
      end

      it "is visible to any admin when the sender is an admin" do
        admin_sender = create(:admin_user)
        CurrentUser.user = admin_sender
        dmail = create(:dmail, from: admin_sender, to: recipient, owner: recipient,
                               no_email_notification: true)
        expect(dmail.visible_to?(admin)).to be true
      end

      it "is not visible to any admin for a regular user-to-user dmail they do not own" do
        expect(dmail.visible_to?(admin)).to be false
      end
    end
  end
end
