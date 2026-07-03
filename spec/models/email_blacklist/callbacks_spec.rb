# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       EmailBlacklist Callbacks                              #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # after_create :invalidate_cache
  # after_destroy :invalidate_cache
  # ---------------------------------------------------------------------------
  describe "cache invalidation" do
    it "clears the banned_emails cache after create" do
      allow(Cache).to receive(:delete)
      create(:email_blacklist)
      expect(Cache).to have_received(:delete).with("banned_emails").at_least(:once)
    end

    it "clears the banned_emails cache after destroy" do
      entry = create(:email_blacklist)
      allow(Cache).to receive(:delete)
      entry.destroy!
      expect(Cache).to have_received(:delete).with("banned_emails").at_least(:once)
    end
  end

  # ---------------------------------------------------------------------------
  # after_create :unverify_accounts
  # ---------------------------------------------------------------------------
  describe "unverify_accounts" do
    let(:domain) { "blacklisted.example.com" }

    it "marks users with a matching email domain as unverified" do
      user = create(:user, email: "someone@blacklisted.example.com")
      create(:email_blacklist, domain: domain)
      expect(user.reload.email_verification_key).to eq("1")
    end

    it "does not affect users with a different email domain" do
      user = create(:user, email: "someone@safe.example.com")
      create(:email_blacklist, domain: domain)
      expect(user.reload.email_verification_key).not_to eq("1")
    end

    it "skips unverification when the matching user count exceeds the threshold" do
      user = create(:user, email: "someone@blacklisted.example.com")
      mock_relation = instance_double(ActiveRecord::Relation, count: EmailBlacklist::UNVERIFY_COUNT_TRESHOLD + 1, each: [])
      allow(User).to receive(:search).and_return(mock_relation)

      create(:email_blacklist, domain: domain)

      expect(user.reload.email_verification_key).not_to eq("1")
    end
  end
end
