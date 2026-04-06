# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        EmailBlacklist Search                                #
# --------------------------------------------------------------------------- #

RSpec.describe EmailBlacklist do
  include_context "as admin"

  let!(:entry_alpha) { create(:email_blacklist, domain: "alpha.example.com", reason: "Phishing site") }
  let!(:entry_beta)  { create(:email_blacklist, domain: "beta.example.com",  reason: "Known spam source") }
  let!(:entry_gamma) { create(:email_blacklist, domain: "gamma.example.com", reason: "Malware distributor") }

  # ---------------------------------------------------------------------------
  # domain param
  # ---------------------------------------------------------------------------
  describe "domain param" do
    it "returns entries whose domain matches the search term" do
      result = EmailBlacklist.search(domain: "alpha*")
      expect(result).to include(entry_alpha)
      expect(result).not_to include(entry_beta, entry_gamma)
    end

    it "supports a substring match" do
      result = EmailBlacklist.search(domain: "*example*")
      expect(result).to include(entry_alpha, entry_beta, entry_gamma)
    end

    it "returns all entries when domain param is absent" do
      result = EmailBlacklist.search({})
      expect(result).to include(entry_alpha, entry_beta, entry_gamma)
    end
  end

  # ---------------------------------------------------------------------------
  # reason param
  # ---------------------------------------------------------------------------
  describe "reason param" do
    it "returns entries whose reason matches the search term" do
      result = EmailBlacklist.search(reason: "Phishing*")
      expect(result).to include(entry_alpha)
      expect(result).not_to include(entry_beta, entry_gamma)
    end

    it "supports a substring match" do
      result = EmailBlacklist.search(reason: "*spam*")
      expect(result).to include(entry_beta)
      expect(result).not_to include(entry_alpha, entry_gamma)
    end

    it "returns all entries when reason param is absent" do
      result = EmailBlacklist.search({})
      expect(result).to include(entry_alpha, entry_beta, entry_gamma)
    end
  end

  # ---------------------------------------------------------------------------
  # order param
  # ---------------------------------------------------------------------------
  describe "order param" do
    it "orders by domain alphabetically when order is 'domain'" do
      ids = EmailBlacklist.search(order: "domain").ids
      expect(ids.index(entry_alpha.id)).to be < ids.index(entry_beta.id)
      expect(ids.index(entry_beta.id)).to be < ids.index(entry_gamma.id)
    end

    it "orders by reason alphabetically when order is 'reason'" do
      # alpha → "Malware distributor" (gamma), "Known spam source" (beta), "Phishing site" (alpha)
      # alphabetically: Malware < Known? No — K < M < P — so beta < gamma < alpha
      ids = EmailBlacklist.search(order: "reason").ids
      expect(ids.index(entry_beta.id)).to be < ids.index(entry_gamma.id)
      expect(ids.index(entry_gamma.id)).to be < ids.index(entry_alpha.id)
    end

    it "applies default ordering when order param is absent" do
      expect { EmailBlacklist.search({}).to_a }.not_to raise_error
    end
  end
end
