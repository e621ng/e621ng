# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                          Dmail Search & Scopes                              #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  include_context "as admin"

  let(:sender)    { CurrentUser.user }
  let(:recipient) { create(:user) }

  def make_dmail(overrides = {})
    create(:dmail, from: sender, to: recipient, **overrides)
  end

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  describe "scopes" do
    describe ".active" do
      let!(:active_dmail)  { make_dmail(is_deleted: false) }
      let!(:deleted_dmail) { make_dmail(is_deleted: true) }

      it "includes non-deleted dmails" do
        expect(Dmail.active).to include(active_dmail)
      end

      it "excludes deleted dmails" do
        expect(Dmail.active).not_to include(deleted_dmail)
      end
    end

    describe ".deleted" do
      let!(:active_dmail)  { make_dmail(is_deleted: false) }
      let!(:deleted_dmail) { make_dmail(is_deleted: true) }

      it "includes deleted dmails" do
        expect(Dmail.deleted).to include(deleted_dmail)
      end

      it "excludes active dmails" do
        expect(Dmail.deleted).not_to include(active_dmail)
      end
    end

    describe ".read" do
      let!(:read_dmail)   { make_dmail(is_read: true) }
      let!(:unread_dmail) { make_dmail(is_read: false) }

      it "includes read dmails" do
        expect(Dmail.read).to include(read_dmail)
      end

      it "excludes unread dmails" do
        expect(Dmail.read).not_to include(unread_dmail)
      end
    end

    describe ".unread" do
      let!(:unread_active)  { make_dmail(is_read: false, is_deleted: false) }
      let!(:read_dmail)     { make_dmail(is_read: true,  is_deleted: false) }
      let!(:unread_deleted) { make_dmail(is_read: false, is_deleted: true) }

      it "includes unread, non-deleted dmails" do
        expect(Dmail.unread).to include(unread_active)
      end

      it "excludes read dmails" do
        expect(Dmail.unread).not_to include(read_dmail)
      end

      it "excludes deleted unread dmails" do
        expect(Dmail.unread).not_to include(unread_deleted)
      end
    end

    describe ".visible" do
      let!(:owned)     { make_dmail }                # owner = recipient
      let!(:not_owned) { make_dmail(owner: sender) } # owner = sender (CurrentUser = admin/sender)

      it "includes dmails owned by the current user" do
        # Temporarily switch to recipient to test their visibility
        CurrentUser.user = recipient
        expect(Dmail.visible).to include(owned)
      end

      it "excludes dmails owned by someone else" do
        CurrentUser.user = recipient
        expect(Dmail.visible).not_to include(not_owned)
      end
    end

    describe ".sent_by" do
      let(:other_sender) { create(:user) }
      let!(:dmail_from_sender) do # recipient's copy
        make_dmail(owner: recipient)
      end
      let!(:dmail_from_other_sender) do
        create(:dmail, from: other_sender, to: recipient, # other sender's copy
                       owner: recipient, no_email_notification: true)
      end

      it "returns dmails sent by the given user (not their own copies)" do
        expect(Dmail.sent_by(sender)).to include(dmail_from_sender)
      end

      it "excludes dmails sent by other users" do
        expect(Dmail.sent_by(sender)).not_to include(dmail_from_other_sender)
      end
    end

    describe ".sent_by_id" do
      let!(:dmail_from_sender) { make_dmail(owner: recipient) }
      let(:other_sender)       { create(:user) }
      let!(:other_dmail) do
        create(:dmail, from: other_sender, to: recipient,
                       owner: recipient, no_email_notification: true)
      end

      it "returns dmails sent by the given user ID" do
        expect(Dmail.sent_by_id(sender.id)).to include(dmail_from_sender)
      end

      it "excludes dmails not sent by the given user ID" do
        expect(Dmail.sent_by_id(sender.id)).not_to include(other_dmail)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .search
  # ---------------------------------------------------------------------------
  describe ".search" do
    let!(:dmail_a) { make_dmail(title: "Hello World",   body: "First message body.") }
    let!(:dmail_b) { make_dmail(title: "Goodbye World", body: "Second message body.") }

    describe "title_matches param" do
      it "returns dmails with an exact matching title" do
        result = Dmail.search(title_matches: "Hello World")
        expect(result).to include(dmail_a)
        expect(result).not_to include(dmail_b)
      end

      it "returns dmails matching a wildcard title" do
        result = Dmail.search(title_matches: "Hello*")
        expect(result).to include(dmail_a)
        expect(result).not_to include(dmail_b)
      end
    end

    describe "message_matches param" do
      it "returns dmails whose body contains the search term" do
        result = Dmail.search(message_matches: "First*")
        expect(result).to include(dmail_a)
        expect(result).not_to include(dmail_b)
      end
    end

    describe "to_id param" do
      let(:other_recipient) { create(:user) }
      let!(:dmail_other)    do
        create(:dmail, from: sender, to: other_recipient,
                       owner: other_recipient, no_email_notification: true)
      end

      it "filters by recipient id" do
        result = Dmail.search(to_id: recipient.id.to_s)
        expect(result).to include(dmail_a, dmail_b)
        expect(result).not_to include(dmail_other)
      end
    end

    describe "from_id param" do
      let(:other_sender2) { create(:user) }
      let!(:dmail_other)  do
        create(:dmail, from: other_sender2, to: recipient,
                       owner: recipient, no_email_notification: true)
      end

      it "filters by sender id" do
        result = Dmail.search(from_id: sender.id.to_s)
        expect(result).to include(dmail_a, dmail_b)
        expect(result).not_to include(dmail_other)
      end
    end

    describe "is_read param" do
      let!(:read_dmail)   { make_dmail(is_read: true) }
      let!(:unread_dmail) { make_dmail(is_read: false) }

      it "returns only read dmails when is_read is true" do
        result = Dmail.search(is_read: "true")
        expect(result).to include(read_dmail)
        expect(result).not_to include(unread_dmail)
      end
    end

    describe "is_deleted param" do
      let!(:active_dmail)  { make_dmail(is_deleted: false) }
      let!(:deleted_dmail) { make_dmail(is_deleted: true) }

      it "returns only deleted dmails when is_deleted is true" do
        result = Dmail.search(is_deleted: "true")
        expect(result).to include(deleted_dmail)
        expect(result).not_to include(active_dmail)
      end
    end

    describe "read param" do
      let!(:read_dmail)   { make_dmail(is_read: true,  is_deleted: false) }
      let!(:unread_dmail) { make_dmail(is_read: false, is_deleted: false) }

      it "applies .read scope when read is truthy" do
        result = Dmail.search(read: "true")
        expect(result).to include(read_dmail)
        expect(result).not_to include(unread_dmail)
      end

      it "applies .unread scope when read is falsy" do
        result = Dmail.search(read: "false")
        expect(result).to include(unread_dmail)
        expect(result).not_to include(read_dmail)
      end
    end

    describe "default ordering" do
      it "returns results newest first (descending id)" do
        ids = Dmail.search({}).ids
        expect(ids.index(dmail_b.id)).to be < ids.index(dmail_a.id)
      end
    end
  end
end
