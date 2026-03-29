# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "SourceMethods" do
    describe "#source_array" do
      it "returns an empty array when source is blank" do
        post = build(:post, source: "")
        expect(post.source_array).to eq([])
      end

      it "returns a single-element array for a single source" do
        post = build(:post, source: "https://example.com")
        expect(post.source_array).to eq(["https://example.com"])
      end

      it "splits multiple sources on newlines" do
        post = build(:post, source: "https://first.example.com\nhttps://second.example.com")
        expect(post.source_array).to eq(["https://first.example.com", "https://second.example.com"])
      end
    end

    describe "#apply_source_diff" do
      it "adds a source when provided without a minus prefix" do
        post = create(:post, source: "https://original.example.com")
        post.source_diff = "https://new.example.com"
        post.apply_source_diff
        expect(post.source_array).to include("https://new.example.com")
        expect(post.source_array).to include("https://original.example.com")
      end

      it "removes a source when provided with a minus prefix" do
        post = create(:post, source: "https://original.example.com\nhttps://other.example.com")
        post.source_diff = "-https://original.example.com"
        post.apply_source_diff
        expect(post.source_array).not_to include("https://original.example.com")
        expect(post.source_array).to include("https://other.example.com")
      end

      it "does nothing when source_diff is blank" do
        post = create(:post, source: "https://example.com")
        post.source_diff = ""
        original = post.source
        post.apply_source_diff
        expect(post.source).to eq(original)
      end

      it "handles URL-encoded %0A as a line separator in source_diff" do
        post = create(:post, source: "https://original.example.com")
        post.source_diff = "https://new.example.com%0Ahttps://another.example.com"
        post.apply_source_diff
        expect(post.source_array).to include("https://new.example.com")
        expect(post.source_array).to include("https://another.example.com")
      end

      it "strips surrounding quotes from source entries in the diff" do
        post = create(:post, source: '"https://quoted.example.com"')
        post.source_diff = '-"https://quoted.example.com"'
        post.apply_source_diff
        expect(post.source_array).not_to include("https://quoted.example.com")
      end
    end

    describe "#strip_source (via before_validation)" do
      it "converts a whitespace-only source to an empty string" do
        post = build(:post, source: "   ")
        post.valid?
        expect(post.source).to eq("")
      end

      it "normalizes \\r\\n newlines to \\n within the source" do
        post = build(:post, source: "https://a.example.com\r\nhttps://b.example.com")
        post.valid?
        expect(post.source).not_to include("\r")
      end
    end
  end
end
