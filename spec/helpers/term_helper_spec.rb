# frozen_string_literal: true

require "rails_helper"

RSpec.describe TermHelper do
  before do
    stub_const("TermHelper::TERMS", { "artist": "director", "user": "member", "spaced term": "map" }.freeze)
    TermHelper::CACHE.clear
  end

  describe ".format" do
    subject(:result) { described_class.format(text, **vars) }

    let(:vars) { {} }

    context "with a standard string (no substitutions)" do
      let(:text) { "Settings profile" }

      it { is_expected.to eq("Settings profile") }
    end

    context "with a known term" do
      let(:text) { "Delete {{artist}}" }

      it { is_expected.to eq("Delete director") }
    end

    context "with an unknown term" do
      let(:text) { "Delete {{unknown}}" }

      it "removes the braces and leaves the inner term unmodified" do
        expect(result).to eq("Delete unknown")
      end
    end

    context "with multiple terms" do
      let(:text) { "{{user}} #4 is {{artist}} #2" }

      it { is_expected.to eq("member #4 is director #2") }
    end

    context "with a term containing spaces" do
      let(:text) { "It's a {{spaced term}}!" }

      it { is_expected.to eq("It's a map!") }
    end

    context "with runtime interpolation variables" do
      let(:text) { "Deleted {{artist}} #%<id>s" }
      let(:vars) { { id: 42 } }

      it "swaps the term and interpolates the variable" do
        expect(result).to eq("Deleted director #42")
      end
    end

    context "with an unfrozen string" do
      let(:text) { String.new("Hello {{user}}") }

      before do
        allow(Rails.logger).to receive(:error)
      end

      it "processes the string correctly" do
        expect(result).to eq("Hello member")
      end

      it "logs an error to Rails.logger" do
        result
        expect(Rails.logger).to have_received(:error).with(/Not a frozen string: "Hello \{\{user\}\}"/)
      end
    end

    context "when the cache size exceeds the maximum limit" do
      let(:text) { "Cache test {{artist}}" }

      before do
        allow(TermHelper::CACHE).to receive(:size).and_return(TermHelper::MAX_CACHE_SIZE)
        allow(TermHelper::CACHE).to receive(:clear).and_call_original
        allow(Rails.logger).to receive(:warn)
      end

      it "clears the cache" do
        result
        expect(TermHelper::CACHE).to have_received(:clear)
      end

      it "logs a warning to Rails.logger" do
        result
        expect(Rails.logger).to have_received(:warn).with(/TermHelper cache exceeded #{TermHelper::MAX_CACHE_SIZE} entries and was purged/)
      end
    end
  end

  describe "#tm" do
    let(:text) { "Hello {{user}}" }

    before do
      allow(TermHelper).to receive(:format).and_return("Delegated Response")
    end

    it "delegates directly to TermHelper.format" do
      expect(tm(text, id: 1)).to eq("Delegated Response")
      expect(TermHelper).to have_received(:format).with(text, id: 1)
    end
  end
end
