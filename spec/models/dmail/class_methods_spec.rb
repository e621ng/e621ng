# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         Dmail Class Methods & Callbacks                     #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  # Use admin as the sender so that `from.is_janitor?` returns true and the
  # recipient's copy skips rate-limit checks inside `user_not_limited`.
  include_context "as admin"

  let(:sender)    { CurrentUser.user }
  let(:recipient) { create(:user) }

  def split_params(overrides = {})
    {
      title:                 "Test Subject",
      body:                  "Test body.",
      to_id:                 recipient.id,
      from_id:               sender.id,
      no_email_notification: true,
    }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # .create_split
  # ---------------------------------------------------------------------------
  describe ".create_split" do
    it "creates two Dmail records — one per participant" do
      expect { Dmail.create_split(split_params) }.to change(Dmail, :count).by(2)
    end

    it "returns the sender's copy" do
      result = Dmail.create_split(split_params)
      expect(result.owner_id).to eq(sender.id)
    end

    it "marks the sender's copy as already read" do
      result = Dmail.create_split(split_params)
      expect(result.is_read).to be true
    end

    it "leaves the recipient's copy unread" do
      Dmail.create_split(split_params)
      recipient_copy = Dmail.find_by(owner_id: recipient.id)
      expect(recipient_copy.is_read).to be false
    end

    it "sets owner_id = to_id on the recipient's copy" do
      Dmail.create_split(split_params)
      recipient_copy = Dmail.find_by(owner_id: recipient.id)
      expect(recipient_copy.owner_id).to eq(recipient.id)
    end

    it "rolls back both copies when the recipient's copy fails validation" do
      # An invalid to_id causes recipient_accepts_dmails to fail
      expect do
        Dmail.create_split(split_params(to_id: -1))
      end.not_to change(Dmail, :count)
    end

    it "creates only one record when to_id == from_id (self-message)" do
      expect do
        Dmail.create_split(split_params(to_id: sender.id))
      end.to change(Dmail, :count).by(1)
    end
  end

  # ---------------------------------------------------------------------------
  # .create_automated
  # ---------------------------------------------------------------------------
  describe ".create_automated" do
    it "persists a new Dmail" do
      expect do
        Dmail.create_automated(to: recipient, title: "System notice", body: "Hello.", no_email_notification: true)
      end.to change(Dmail, :count).by(1)
    end

    it "sets from to the system user" do
      dmail = Dmail.create_automated(to: recipient, title: "System notice", body: "Hello.", no_email_notification: true)
      expect(dmail.from_id).to eq(User.system.id)
    end

    it "sets owner to the recipient" do
      dmail = Dmail.create_automated(to: recipient, title: "System notice", body: "Hello.", no_email_notification: true)
      expect(dmail.owner_id).to eq(recipient.id)
    end
  end

  # ---------------------------------------------------------------------------
  # #update_recipient_unread_count (after_create callback)
  # ---------------------------------------------------------------------------
  describe "#update_recipient_unread_count" do
    it "increments the recipient's unread_dmail_count when a recipient's copy is created" do
      expect do
        create(:dmail, from: sender, to: recipient, no_email_notification: true)
        recipient.reload
      end.to change(recipient, :unread_dmail_count).by(1)
    end

    it "does not increment when the owner is the CurrentUser (sender's copy)" do
      # Build and save a sender's copy directly (owner = sender = CurrentUser)
      expect do
        dmail = build(:dmail, from: sender, to: recipient, owner: sender,
                              is_read: true, no_email_notification: true)
        dmail.save!
        recipient.reload
      end.not_to change(recipient, :unread_dmail_count)
    end

    it "does not increment when the dmail is already read" do
      expect do
        create(:dmail, from: sender, to: recipient, is_read: true, no_email_notification: true)
        recipient.reload
      end.not_to change(recipient, :unread_dmail_count)
    end

    it "does not increment when the dmail is deleted" do
      expect do
        create(:dmail, from: sender, to: recipient, is_deleted: true, no_email_notification: true)
        recipient.reload
      end.not_to change(recipient, :unread_dmail_count)
    end
  end

  # ---------------------------------------------------------------------------
  # #auto_read_if_filtered (before_create callback)
  # ---------------------------------------------------------------------------
  describe "#auto_read_if_filtered" do
    it "marks the recipient's copy as read when the recipient has a matching filter" do
      # DmailFilter#filtered? requires from.level < MODERATOR, so use a plain user as sender
      regular_sender = create(:user)
      CurrentUser.user = recipient
      DmailFilter.create!(words: "spam")
      CurrentUser.user = regular_sender

      dmail = create(:dmail, from: regular_sender, to: recipient,
                             body: "This is spam content.", no_email_notification: true)
      expect(dmail.reload.is_read).to be true
    end

    it "leaves is_read as false when the recipient has no matching filter" do
      regular_sender = create(:user)
      CurrentUser.user = regular_sender
      dmail = create(:dmail, from: regular_sender, to: recipient,
                             body: "A normal message.", no_email_notification: true)
      expect(dmail.reload.is_read).to be false
    end

    it "does not auto-read the sender's copy even when the sender has a matching filter" do
      regular_sender = create(:user)
      CurrentUser.user = regular_sender
      DmailFilter.create!(words: "spam")

      # sender's copy: owner_id = sender.id = CurrentUser.id, so callback skips
      dmail = build(:dmail, from: regular_sender, to: recipient, owner: regular_sender,
                            body: "This is spam content.", is_read: false, no_email_notification: true)
      dmail.save!
      expect(dmail.reload.is_read).to be false
    end
  end
end
