# frozen_string_literal: true

require "rails_helper"

RSpec.describe CurrentSite do
  # Site safe mode is decided here alone; reading the config value directly
  # elsewhere would skip site profiles (doc 38).
  it "is the only reader of Danbooru.config.safe_mode?" do
    files = Rails.root.glob("{app,config,lib}/**/*.{rb,erb}")
    readers = files.select { |f| f.read.include?("Danbooru.config.safe_mode?") }
    expect(readers.map { |f| f.relative_path_from(Rails.root).to_s }).to eq(["app/logical/current_site.rb"])
  end

  context "without profiles" do
    it "is the primary site" do
      expect(described_class.id).to eq("e621")
      expect(described_class).to be_primary
      expect(described_class.cache_key).to be_nil
      expect(described_class.cache_keys).to eq([nil])
      expect(described_class.safe_mode?).to be(false)
    end

    it "forces safe mode when the deployment is configured as a safe-mode site" do
      allow(Danbooru.config.custom_configuration).to receive(:safe_mode?).and_return(true)
      expect(described_class.safe_mode?).to be(true)
    end
  end

  context "with an e926 profile" do
    include_context "with e926 site profile"

    it "lists the sites" do
      expect(described_class.ids).to eq(%w[e621 e926])
      expect(described_class.cache_keys).to eq([nil, "e926"])
    end

    it "finds sites by id and host" do
      expect(described_class.find(nil)).to be_primary
      expect(described_class.find("e621")).to be_primary
      expect(described_class.find("e926").id).to eq("e926")
      expect(described_class.find("bogus")).to be_nil
      expect(described_class.for_host("www.e926.net").id).to eq("e926")
      expect(described_class.for_host("e621.net")).to be_nil
    end

    it "freezes overrides" do
      overrides = described_class.find("e926").overrides
      expect(overrides).to be_frozen
      expect(overrides[:ads_config][:areas]).to be_frozen
    end

    describe ".with" do
      it "runs the block as the site and restores the previous state" do
        CurrentUser.safe_mode = false
        inside = described_class.with("e926") { [described_class.id, described_class.safe_mode?, CurrentUser.safe_mode?] }

        expect(inside).to eq(["e926", true, true])
        expect(described_class.id).to eq("e621")
        expect(described_class.safe_mode?).to be(false)
        expect(CurrentUser.safe_mode?).to be(false)
      end

      it "restores the previous state when the block raises" do
        expect { described_class.with("e926") { raise "boom" } }.to raise_error("boom")
        expect(described_class.id).to eq("e621")
        expect(described_class.safe_mode?).to be(false)
      end

      it "raises for an unknown site" do
        expect { described_class.with("bogus") { nil } }.to raise_error(ArgumentError, /Unknown site/)
      end
    end
  end
end
