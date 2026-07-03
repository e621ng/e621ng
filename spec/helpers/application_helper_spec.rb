# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper do
  describe "#error_messages_for" do
    subject(:markup) { helper.error_messages_for(:artist) }

    context "when the instance variable is unset" do
      it { is_expected.to eq("") }
    end

    context "when the record has no errors" do
      before { assign(:artist, build(:artist)) }

      it { is_expected.to eq("") }
    end

    context "when the record has errors" do
      before do
        artist = Artist.new
        artist.errors.add(:name, "is invalid")
        assign(:artist, artist)
      end

      it "renders the wrapper markup" do
        expect(markup).to include('<div class="error-messages ui-state-error ui-corner-all">')
        expect(markup).to include("<strong>Error</strong>")
        expect(markup).to include("Name is invalid")
      end

      it "returns an html_safe string" do
        expect(markup).to be_html_safe
      end
    end

    context "when an error message contains HTML from user input" do
      let(:payload) { %(<style>*{display:none}</style><script>alert(1)</script>) }

      before do
        artist = Artist.new
        # Mirrors TagNameValidator, which interpolates the raw value into the message.
        artist.errors.add(:name, "'#{payload}' cannot contain asterisks ('*')")
        assign(:artist, artist)
      end

      it "escapes the injected markup rather than emitting it raw" do
        expect(markup).not_to include("<script>")
        expect(markup).not_to include("<style>")
        expect(markup).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
      end
    end
  end
end
