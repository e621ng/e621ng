# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        Dmail Instance Methods                               #
# --------------------------------------------------------------------------- #

RSpec.describe Dmail do
  let(:sender)    { create(:user) }
  let(:recipient) { create(:user) }

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
  # #mark_as_read!
  # ---------------------------------------------------------------------------
  describe "#mark_as_read!" do
    it "sets is_read to true" do
      dmail = make_dmail
      expect { dmail.mark_as_read! }.to change { dmail.reload.is_read }.from(false).to(true)
    end

    it "decrements the owner's unread_dmail_count by 1" do
      dmail = make_dmail
      # after_create increments recipient's count; verify then decrement
      recipient.reload
      expect { dmail.mark_as_read! }.to change { recipient.reload.unread_dmail_count }.by(-1)
    end

    it "is a no-op when the dmail is already read" do
      dmail = make_dmail(is_read: true)
      recipient.reload
      expect { dmail.mark_as_read! }.not_to(change { recipient.reload.unread_dmail_count })
      expect(dmail.reload.is_read).to be true
    end

    it "calls recalculate_unread_dmail_count! when the stored count is 0 or negative" do
      dmail = make_dmail
      recipient.update_columns(unread_dmail_count: 0)
      # Eagerly load the owner association so dmail caches this object.
      # Stubbing after reload would target a different Ruby instance.
      owner = dmail.owner
      allow(owner).to receive(:recalculate_unread_dmail_count!)
      dmail.mark_as_read!
      expect(owner).to have_received(:recalculate_unread_dmail_count!)
    end
  end

  # ---------------------------------------------------------------------------
  # #mark_as_unread!
  # ---------------------------------------------------------------------------
  describe "#mark_as_unread!" do
    it "sets is_read to false" do
      dmail = make_dmail(is_read: true)
      expect { dmail.mark_as_unread! }.to change { dmail.reload.is_read }.from(true).to(false)
    end

    it "increments the owner's unread_dmail_count by 1" do
      dmail = make_dmail(is_read: true)
      expect { dmail.mark_as_unread! }.to change { recipient.reload.unread_dmail_count }.by(1)
    end
  end

  # ---------------------------------------------------------------------------
  # #is_automated?
  # ---------------------------------------------------------------------------
  describe "#is_automated?" do
    it "returns true when from is the system user" do
      dmail = create(:dmail, from: User.system, to: recipient, owner: recipient,
                             bypass_limits: true, no_email_notification: true)
      expect(dmail.is_automated?).to be true
    end

    it "returns false for a regular sender" do
      expect(make_dmail.is_automated?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # #quoted_body
  # ---------------------------------------------------------------------------
  describe "#quoted_body" do
    it "wraps the body in a section tag attributed to the sender" do
      dmail = make_dmail(body: "Hello there.")
      expect(dmail.quoted_body).to include("[section=#{sender.pretty_name} said:]")
      expect(dmail.quoted_body).to include("Hello there.")
      expect(dmail.quoted_body).to include("[/section]")
    end
  end

  # ---------------------------------------------------------------------------
  # #build_response
  # ---------------------------------------------------------------------------
  describe "#build_response" do
    it "prepends 'Re: ' to the title when not already present" do
      dmail    = make_dmail(title: "Original subject")
      response = dmail.build_response
      expect(response.title).to eq("Re: Original subject")
    end

    it "does not double-prepend 'Re:' when the title already starts with it" do
      dmail    = make_dmail(title: "Re: Already a reply")
      response = dmail.build_response
      expect(response.title).to eq("Re: Already a reply")
    end

    it "sets to_id to the original sender" do
      dmail    = make_dmail
      response = dmail.build_response
      expect(response.to_id).to eq(sender.id)
    end

    it "sets from_id to the original recipient" do
      dmail    = make_dmail
      response = dmail.build_response
      expect(response.from_id).to eq(recipient.id)
    end

    it "prefills body with the quoted original body" do
      dmail    = make_dmail(body: "Original message.")
      response = dmail.build_response
      expect(response.body).to eq(dmail.quoted_body)
    end

    it "does not set to_id when the :forward option is given" do
      dmail    = make_dmail
      response = dmail.build_response(forward: true)
      expect(response.to_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #to_name= (AddressMethods)
  # ---------------------------------------------------------------------------
  describe "#to_name=" do
    it "sets to_id by looking up the user by name" do
      dmail = build(:dmail)
      dmail.to_name = recipient.name
      expect(dmail.to_id).to eq(recipient.id)
    end

    it "sets to_id to nil when the name does not match any user" do
      dmail = build(:dmail)
      dmail.to_name = "nonexistent_user_xyz"
      expect(dmail.to_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # #filtered?
  # ---------------------------------------------------------------------------
  describe "#filtered?" do
    # The filter must be created BEFORE the dmail. Creating it after causes
    # auto_read_if_filtered (before_create) to cache `to.dmail_filter = nil`
    # on the recipient object; subsequent calls then see the stale nil.
    #
    # DmailFilter#filtered? uses String#=~, which returns Integer or nil (never
    # false), so we assert be_truthy / be_falsy rather than be true / be false.

    it "returns truthy when CurrentUser has a dmail filter matching the body" do
      CurrentUser.user = recipient
      DmailFilter.create!(words: "spamword")
      CurrentUser.user = sender
      dmail = make_dmail(body: "This message contains spamword content.")
      CurrentUser.user = recipient
      expect(dmail).to be_filtered
    end

    it "returns falsy when CurrentUser has a filter that does not match" do
      CurrentUser.user = recipient
      DmailFilter.create!(words: "xyznonmatch")
      CurrentUser.user = sender
      dmail = make_dmail(body: "A perfectly normal message.")
      CurrentUser.user = recipient
      expect(dmail).not_to be_filtered
    end

    it "returns falsy when CurrentUser has no dmail filter at all" do
      dmail = make_dmail
      CurrentUser.user = recipient
      expect(dmail).not_to be_filtered
    end
  end
end
