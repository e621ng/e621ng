# frozen_string_literal: true

require "rails_helper"

RSpec.describe IconHelper do
  describe "#copy_button" do
    subject(:button) { Nokogiri::HTML.fragment(helper.copy_button(text, label: "tag")).at_css("button") }

    let(:text) { "some_tag" }

    it "renders a copy button carrying the text" do
      expect(button["type"]).to eq("button")
      expect(button["class"]).to eq("copy-button")
      expect(button["data-copy-text"]).to eq("some_tag")
      expect(button["data-copy-label"]).to eq("tag")
      expect(button["title"]).to eq("Copy tag to clipboard")
    end

    it "includes the copy icon" do
      expect(button.at_css("svg[name='copy']")).to be_present
    end

    context "with markup in the text" do
      let(:text) { %("><script>alert(1)</script>) }

      it "escapes it into the attribute" do
        expect(button["data-copy-text"]).to eq(text)
        expect(button.at_css("script")).to be_nil
      end
    end
  end
end
