# frozen_string_literal: true

require "rails_helper"

RSpec.describe AutomodUserCheckJob do
  include_context "as admin"

  let(:user) { create(:user, name: "normaluser") }

  def perform(user_id = user.id, check_username: false, check_profile: false)
    described_class.perform_now(user_id, check_username: check_username, check_profile: check_profile)
  end

  describe "username checks" do
    it "creates a ticket when the username matches a usernames rule" do
      rule = create(:automod_rule, :for_usernames, regex: "badword")
      user.update_columns(name: "badworduser")
      expect { perform(check_username: true) }.to change(Ticket, :count).by(1)
      ticket = Ticket.last
      expect(ticket.qtype).to eq("user")
      expect(ticket.disp_id).to eq(user.id)
      expect(ticket.reason).to include(rule.name)
    end

    it "does not create a ticket when the username does not match" do
      create(:automod_rule, :for_usernames, regex: "badword")
      expect { perform(check_username: true) }.not_to change(Ticket, :count)
    end

    it "does not create a ticket when the only matching rule is not a usernames rule" do
      create(:automod_rule, :for_comments, regex: "normaluser")
      expect { perform(check_username: true) }.not_to change(Ticket, :count)
    end
  end

  describe "profile text checks" do
    it "creates a ticket when profile_about matches a profile_text rule" do
      create(:automod_rule, :for_profile_text, regex: "badcontent")
      user.update_columns(profile_about: "this is badcontent")
      expect { perform(check_profile: true) }.to change(Ticket, :count).by(1)
      expect(Ticket.last.qtype).to eq("user")
    end

    it "creates a ticket when profile_artinfo matches a profile_text rule" do
      create(:automod_rule, :for_profile_text, regex: "badcontent")
      user.update_columns(profile_artinfo: "this is badcontent")
      expect { perform(check_profile: true) }.to change(Ticket, :count).by(1)
    end

    it "does not create a ticket when the only matching rule is not a profile_text rule" do
      create(:automod_rule, :for_comments, regex: "normaluser")
      user.update_columns(profile_about: "normaluser profile")
      expect { perform(check_profile: true) }.not_to change(Ticket, :count)
    end
  end

  describe "username check takes priority over profile check" do
    it "creates only one ticket from the username match when both username and profile match" do
      username_rule = create(:automod_rule, :for_usernames, regex: "badword")
      create(:automod_rule, :for_profile_text, regex: "also_bad")
      user.update_columns(name: "badworduser", profile_about: "also_bad content")
      expect { perform(check_username: true, check_profile: true) }.to change(Ticket, :count).by(1)
      expect(Ticket.last.reason).to include(username_rule.name)
    end
  end

  describe "duplicate ticket prevention" do
    it "does not create a ticket when an active user ticket already exists" do
      create(:automod_rule, :for_usernames, regex: "badword")
      user.update_columns(name: "badworduser")
      CurrentUser.as_system do
        Ticket.create!(
          creator_id: User.system.id,
          creator_ip_addr: "127.0.0.1",
          disp_id: user.id,
          status: "pending",
          qtype: "user",
          reason: "existing ticket",
        )
      end
      expect { perform(check_username: true) }.not_to change(Ticket, :count)
    end
  end

  describe "disabled rules" do
    it "does not create a ticket when the matching rule is disabled" do
      create(:disabled_automod_rule, :for_usernames, regex: "normaluser")
      expect { perform(check_username: true) }.not_to change(Ticket, :count)
    end
  end

  describe "no-op when neither check is requested" do
    it "does nothing when both check_username and check_profile are false" do
      create(:automod_rule, :for_usernames, regex: "normaluser")
      expect { perform(check_username: false, check_profile: false) }.not_to change(Ticket, :count)
    end
  end

  describe "error handling" do
    it "handles a deleted user gracefully" do
      user_id = user.id
      user.destroy
      expect { perform(user_id) }.not_to raise_error
    end
  end
end
