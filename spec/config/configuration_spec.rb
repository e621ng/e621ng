# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                    Danbooru configuration sanity checks                     #
# --------------------------------------------------------------------------- #

RSpec.describe Danbooru::EnvironmentConfiguration do
  describe "#validate!" do
    # validate! reads through Danbooru.config (method_missing -> ENV -> custom),
    # so stubbing custom_configuration drives the effective values.
    def stub_config(**values)
      allow(Danbooru.config.custom_configuration).to receive_messages(**values)
    end

    it "accepts the committed default configuration" do
      expect { Danbooru.config.validate! }.not_to raise_error
    end

    it "accepts a valid custom configuration" do
      stub_config(upload_karma_l1_threshold: 50, upload_karma_l10_threshold: 5_000, upload_karma_free_threshold: 3)
      expect { Danbooru.config.validate! }.not_to raise_error
    end

    context "upload_karma_l1_threshold" do
      it "raises when it is zero" do
        stub_config(upload_karma_l1_threshold: 0)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /l1_threshold must be positive/)
      end

      it "raises when it is negative" do
        stub_config(upload_karma_l1_threshold: -5)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /l1_threshold must be positive/)
      end
    end

    context "upload_karma_l10_threshold" do
      it "raises when it is not greater than l1" do
        stub_config(upload_karma_l1_threshold: 100, upload_karma_l10_threshold: 100)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /must be less than upload_karma_l10_threshold/)
      end

      it "raises when it is negative" do
        stub_config(upload_karma_l10_threshold: -1)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError)
      end
    end

    context "upload_karma_free_threshold" do
      it "allows nil (bypass disabled)" do
        stub_config(upload_karma_free_threshold: nil)
        expect { Danbooru.config.validate! }.not_to raise_error
      end

      it "accepts the boundary levels 1 and 10" do
        stub_config(upload_karma_free_threshold: 1)
        expect { Danbooru.config.validate! }.not_to raise_error
        stub_config(upload_karma_free_threshold: 10)
        expect { Danbooru.config.validate! }.not_to raise_error
      end

      it "raises when below 1" do
        stub_config(upload_karma_free_threshold: 0)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /between 1 and 10/)
      end

      it "raises when above 10" do
        stub_config(upload_karma_free_threshold: 11)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /between 1 and 10/)
      end
    end
  end

  describe "site profiles" do
    include_context "with e926 site profile"

    it "uses the config as written on the primary site" do
      expect(Danbooru.config.app_name).to eq("e621")
      expect(Danbooru.config.hostname).to eq(Danbooru.config.custom_configuration.hostname)
    end

    it "applies the overrides of the current site" do
      CurrentSite.with("e926") do
        expect(Danbooru.config.app_name).to eq("e926")
        expect(Danbooru.config.hostname).to eq("e926.net")
        expect(Danbooru.config.description).to eq("e926")
      end
    end

    it "never overrides keys outside SITE_SCOPED" do
      e926_profile[:overrides][:remember_key] = "leak"
      CurrentSite.with("e926") do
        expect(Danbooru.config.remember_key).to eq(Danbooru.config.custom_configuration.remember_key)
      end
    end

    it "replaces values rather than merging them" do
      CurrentSite.with("e926") do
        expect(Danbooru.config.ads_config[:areas].keys).to contain_exactly(:top, :bottom)
      end
    end

    it "lets overrides beat ENV" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("DANBOORU_APP_NAME", nil).and_return("from-env")
      expect(Danbooru.config.app_name).to eq("from-env")
      CurrentSite.with("e926") { expect(Danbooru.config.app_name).to eq("e926") }
    end

    it "bypasses overrides with primary_value" do
      CurrentSite.with("e926") { expect(Danbooru.config.primary_value(:app_name)).to eq("e621") }
    end

    it "routes derived values through the overrides" do
      CurrentSite.with("e926") do
        expect(Danbooru.config.contact_email).to eq("management@e926.net")
        expect(Danbooru.config.totp_issuer).to eq("e926")
      end
    end

    it "keeps safe_app_name on the primary site" do
      CurrentSite.with("e926") { expect(Danbooru.config.safe_app_name).to eq("e621") }
    end

    it "uses storage_base_url in the default storage manager" do
      expect(Danbooru.config.storage_manager.base_url).not_to start_with("https://static1.e926.net")
      CurrentSite.with("e926") do
        expect(Danbooru.config.storage_manager.base_url).to eq("https://static1.e926.net")
      end
    end

    describe "#validate!" do
      def profile_with(**changes)
        { "e926" => e926_profile.merge(changes) }
      end

      def expect_invalid(profiles, message)
        allow(Danbooru.config.custom_configuration).to receive(:site_profiles).and_return(profiles)
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, message)
      end

      it "accepts a valid profile" do
        expect { Danbooru.config.validate! }.not_to raise_error
      end

      it "rejects an invalid site id" do
        expect_invalid({ "E9 26" => e926_profile }, /invalid site id/)
      end

      it "rejects a profile for the primary site" do
        expect_invalid({ "e621" => e926_profile }, /is the primary site/)
      end

      it "rejects missing or uppercase hosts" do
        expect_invalid(profile_with(hosts: []), /hosts must be/)
        expect_invalid(profile_with(hosts: ["E926.net"]), /hosts must be/)
      end

      it "rejects the primary hostname as a profile host" do
        expect_invalid(profile_with(hosts: [Danbooru.config.primary_value(:hostname).downcase]), /claims the primary hostname/)
      end

      it "rejects a host claimed twice" do
        expect_invalid({ "e926" => e926_profile, "pony" => e926_profile }, /is claimed by e926 and pony/)
      end

      it "rejects a non-boolean safe_mode" do
        expect_invalid(profile_with(safe_mode: "yes"), /safe_mode must be true or false/)
      end

      it "rejects overrides outside SITE_SCOPED" do
        expect_invalid(profile_with(overrides: { remember_key: "x" }), /cannot override remember_key/)
      end

      it "rejects secrets in SITE_SCOPED" do
        stub_const("Danbooru::CustomConfiguration::SECRET_KEYS", %w[remember_key hostname])
        expect { Danbooru.config.validate! }.to raise_error(described_class::ValidationError, /includes secrets: hostname/)
      end
    end
  end
end
