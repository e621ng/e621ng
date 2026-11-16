# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacement do
  include_context "as admin"

  describe "#fetch_source_file with upload URL rules" do
    let(:url) { "https://example.com/sample/1.jpg" }
    let(:record) { build(:post_replacement, replacement_url: url, is_backup: false) }

    before do
      allow(UploadWhitelist).to receive(:is_whitelisted?).and_return([true, nil])
      allow(Downloads::File).to receive(:new).and_raise(Downloads::File::Error, "not reached in these examples")
    end

    it "refuses a blocked URL before downloading, naming the rule" do
      create(:blocking_upload_url_rule, label: "Sample URL")
      expect(record).not_to be_valid
      expect(record.errors[:replacement_url].first).to include("is not allowed: Sample URL", "https://example.com/full/1.jpg")
      expect(Downloads::File).not_to have_received(:new)
    end

    it "refuses when a rule fails to evaluate" do
      allow(UploadUrlRule).to receive(:evaluate).and_raise(UploadUrlRule::EvaluationError.new("Slow"))
      expect(record).not_to be_valid
      expect(record.errors[:replacement_url].first).to include("could not be checked: rule 'Slow' failed")
    end

    it "does not block on a recommend rule and downloads with rules enforced" do
      create(:upload_url_rule)
      expect(record).not_to be_valid
      expect(record.errors[:replacement_url]).to eq(["failed to fetch file"])
      expect(Downloads::File).to have_received(:new).with(anything, enforce_rules: true)
    end

    it "shows the rule message when the downloader refuses a redirect target" do
      allow(Downloads::File).to receive(:new).and_raise(Downloads::File::RuleError, "'https://example.com/x' is not allowed: Sample URL.")
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("'https://example.com/x' is not allowed: Sample URL.")
    end

    it "skips the rules when a file is attached" do
      create(:blocking_upload_url_rule)
      allow(UploadUrlRule).to receive(:evaluate).and_call_original
      record.replacement_file = Tempfile.new
      record.valid?
      expect(UploadUrlRule).not_to have_received(:evaluate)
    end
  end
end
