# frozen_string_literal: true

require "rails_helper"

RSpec.describe UploadUrlRule do
  include_context "as admin"

  describe ".canonicalize" do
    let(:canonical) { "https://example.com/a/b.jpg?a=1&b=2" }

    {
      "upper-case scheme and host" => "HTTPS://EXAMPLE.com/a/b.jpg?a=1&b=2",
      "an explicit default port"   => "https://example.com:443/a/b.jpg?a=1&b=2",
      "a trailing dot on the host" => "https://example.com./a/b.jpg?a=1&b=2",
      "repeated slashes"           => "https://example.com//a///b.jpg?a=1&b=2",
      "dot segments"               => "https://example.com/a/./x/../b.jpg?a=1&b=2",
      "a fragment"                 => "https://example.com/a/b.jpg?a=1&b=2#frag",
      "reordered query parameters" => "https://example.com/a/b.jpg?b=2&a=1",
      "percent-encoded unreserved" => "https://example.com/a/%62.jpg?a=1&b=2",
      "userinfo"                   => "https://user:pw@example.com/a/b.jpg?a=1&b=2",
      "surrounding whitespace"     => "  https://example.com/a/b.jpg?a=1&b=2 ",
    }.each do |variation, url|
      it "collapses #{variation}" do
        expect(described_class.canonicalize(url)).to eq(canonical)
      end
    end

    it "accepts an Addressable::URI" do
      expect(described_class.canonicalize(Addressable::URI.parse("https://example.com/a/b.jpg?b=2&a=1"))).to eq(canonical)
    end

    it "drops an empty query" do
      expect(described_class.canonicalize("https://example.com/a?")).to eq("https://example.com/a")
    end

    it "returns nil for non-http(s), blank, hostless and overlong input" do
      expect(described_class.canonicalize("ftp://example.com/a")).to be_nil
      expect(described_class.canonicalize("")).to be_nil
      expect(described_class.canonicalize(nil)).to be_nil
      expect(described_class.canonicalize("https:///a")).to be_nil
      expect(described_class.canonicalize("https://example.com/#{'a' * 2_000}")).to be_nil
    end
  end

  describe ".evaluate" do
    let(:url) { "https://example.com/sample/1.jpg" }

    it "returns nil when no rule matches" do
      create(:upload_url_rule, pattern: "other\\.com/")
      expect(described_class.evaluate(url)).to be_nil
    end

    it "returns the match with a suggested URL" do
      create(:upload_url_rule, label: "Sample", message: "Use the full size.")
      result = described_class.evaluate(url)
      expect(result).to have_attributes(
        handling: "recommend",
        label: "Sample",
        message: "Use the full size.",
        suggested_url: "https://example.com/full/1.jpg",
        canonical_url: url,
      )
    end

    it "matches case-insensitively against the canonical form" do
      create(:upload_url_rule)
      expect(described_class.evaluate("HTTPS://EXAMPLE.COM:443//SAMPLE/1.jpg#x")).not_to be_nil
    end

    it "gives no suggestion when the replacement is blank" do
      create(:upload_url_rule, replacement: "")
      expect(described_class.evaluate(url).suggested_url).to be_nil
    end

    it "gives no suggestion when the replacement changes nothing" do
      create(:upload_url_rule, pattern: "sample", replacement: "sample")
      expect(described_class.evaluate(url).suggested_url).to be_nil
    end

    it "supports group references in the replacement" do
      create(:upload_url_rule, pattern: "/sample/(\\d+)\\.jpg", replacement: "/full/\\1.png")
      expect(described_class.evaluate(url).suggested_url).to eq("https://example.com/full/1.png")
    end

    it "ignores disabled rules" do
      create(:upload_url_rule, enabled: false)
      expect(described_class.evaluate(url)).to be_nil
    end

    it "prefers the first matching rule of the same handling" do
      create(:upload_url_rule, label: "First")
      create(:upload_url_rule, label: "Second")
      expect(described_class.evaluate(url).label).to eq("First")
    end

    it "prefers a block rule over an earlier recommend rule" do
      create(:upload_url_rule, label: "Recommend")
      create(:blocking_upload_url_rule, label: "Block")
      expect(described_class.evaluate(url)).to have_attributes(label: "Block", handling: "block")
    end

    it "returns nil for input that cannot be canonicalised" do
      create(:upload_url_rule, pattern: "sample")
      expect(described_class.evaluate("not a url with sample")).to be_nil
    end

    it "raises UncheckableUrlError for an overlong http(s) URL while a block rule is enabled" do
      create(:blocking_upload_url_rule)
      expect { described_class.evaluate("#{url}?pad=#{'a' * 2_000}") }.to raise_error(described_class::UncheckableUrlError)
    end

    it "raises UncheckableUrlError for an http(s) URL with invalid encoding while a block rule is enabled" do
      create(:blocking_upload_url_rule)
      expect { described_class.evaluate("#{url}\xFF".dup.force_encoding("UTF-8")) }.to raise_error(described_class::UncheckableUrlError)
    end

    it "returns nil for an overlong URL when no block rule is enabled" do
      create(:upload_url_rule)
      create(:blocking_upload_url_rule, enabled: false)
      expect(described_class.evaluate("#{url}?pad=#{'a' * 2_000}")).to be_nil
    end

    it "returns nil for non-http(s) input even while a block rule is enabled" do
      create(:blocking_upload_url_rule)
      expect(described_class.evaluate("not a url")).to be_nil
      expect(described_class.evaluate("")).to be_nil
    end

    it "raises EvaluationError naming the rule when a match times out" do
      create(:upload_url_rule, label: "Slow")
      allow(Regexp).to receive(:new).and_call_original
      slow = instance_double(Regexp)
      allow(slow).to receive(:match?).and_raise(Regexp::TimeoutError)
      allow(Regexp).to receive(:new).with("example\\.com/sample/", Regexp::IGNORECASE, timeout: described_class::MATCH_TIMEOUT).and_return(slow)

      expect { described_class.evaluate(url) }.to raise_error(described_class::EvaluationError) { |e| expect(e.label).to eq("Slow") }
    end

    it "raises EvaluationError for a broken recommend rule even after another rule matched" do
      create(:upload_url_rule, label: "Fine", pattern: "example")
      create(:upload_url_rule, label: "Broken").update_columns(pattern: "sample(")
      expect { described_class.evaluate(url) }.to raise_error(described_class::EvaluationError) { |e| expect(e.label).to eq("Broken") }
    end
  end

  describe ".failure_message" do
    it "names the failed rule" do
      expect(described_class.failure_message(described_class::EvaluationError.new("Slow"))).to include("rule 'Slow' failed")
    end

    it "explains an uncheckable URL" do
      expect(described_class.failure_message(described_class::UncheckableUrlError.new)).to include("longer than 2000 characters")
    end
  end

  describe "#apply" do
    it "applies an unsaved rule" do
      rule = build(:upload_url_rule)
      expect(rule.apply("https://example.com/sample/1.jpg").suggested_url).to eq("https://example.com/full/1.jpg")
      expect(rule.apply("https://example.com/other/1.jpg")).to be_nil
      expect(rule.apply("nonsense")).to be_nil
    end
  end

  describe "caching" do
    it "serves rules from the cache until it is cleared" do
      create(:upload_url_rule)
      url = "https://example.com/sample/1.jpg"
      expect(described_class.evaluate(url)).not_to be_nil

      described_class.update_all(enabled: false) # no callbacks
      expect(described_class.evaluate(url)).not_to be_nil
      described_class.clear_cache
      expect(described_class.evaluate(url)).to be_nil
    end
  end
end
