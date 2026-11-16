# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadUrlRule do
  include_context "as admin"

  describe "ModAction logging" do
    it "logs creation" do
      rule = create(:upload_url_rule, label: "Sample")
      log = ModAction.where(action: "upload_url_rule_create").last
      expect(log[:values]).to include("label" => "Sample", "pattern" => rule.pattern, "handling" => "recommend", "enabled" => true)
    end

    it "logs updates with the previous values, and not as a creation" do
      rule = create(:upload_url_rule, label: "Sample")
      expect(ModAction.where(action: "upload_url_rule_update")).to be_empty

      rule.update!(handling: "block", pattern: "example\\.com/thumb/")
      log = ModAction.where(action: "upload_url_rule_update").last
      expect(log[:values]).to include(
        "handling" => "block",
        "old_handling" => "recommend",
        "pattern" => "example\\.com/thumb/",
        "old_pattern" => "example\\.com/sample/",
        "old_label" => "Sample",
      )
    end

    it "logs deletion" do
      create(:upload_url_rule, label: "Sample").destroy!
      expect(ModAction.where(action: "upload_url_rule_delete").last[:values]).to include("label" => "Sample")
    end
  end

  describe "creator and updater" do
    it "are set from CurrentUser" do
      rule = described_class.create!(label: "Sample", pattern: "sample", handling: "block")
      expect(rule.creator).to eq(CurrentUser.user)
      expect(rule.updater).to eq(CurrentUser.user)
    end
  end

  describe "cache invalidation" do
    it "clears the rule cache on commit" do
      rule = create(:upload_url_rule)
      allow(Cache).to receive(:delete)
      rule.run_callbacks(:commit)
      expect(Cache).to have_received(:delete).with(described_class::CACHE_KEY)
    end
  end
end
