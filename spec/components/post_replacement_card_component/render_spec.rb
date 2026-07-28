# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostReplacementCardComponent, type: :component do
  include_context "as member"

  let(:post_record) { create(:post) }
  let(:replacement) { create(:post_replacement, post: post_record) }

  def render_card(record, **opts)
    with_request_url "/post_replacements" do
      render_inline(described_class.new(post_replacement: record, **opts))
    end
  end

  it "roots the card at replacement-<id> (the AJAX swap key)" do
    doc = render_card(replacement)
    expect(doc.at_css("#replacement-#{replacement.id}.replacement-card")).to be_present
    expect(doc.at_css(".replacement-card")["data-replacement-id"]).to eq(replacement.id.to_s)
  end

  it "always renders a Report link" do
    doc = render_card(replacement)
    expect(doc.at_css("a.replacement-report-action")).to be_present
  end

  describe "timeline chrome" do
    it "renders a status dot and has-timeline class when timeline: true" do
      doc = render_card(replacement, timeline: true)
      expect(doc.at_css(".replacement-card.has-timeline")).to be_present
      expect(doc.at_css(".replacement-dot")).to be_present
    end

    it "omits the dot for the embedded (non-timeline) form" do
      doc = render_card(replacement, timeline: false)
      expect(doc.at_css(".has-timeline")).to be_nil
      expect(doc.at_css(".replacement-dot")).to be_nil
    end
  end

  describe "default expansion" do
    it "expands pending replacements" do
      doc = render_card(create(:pending_post_replacement, post: post_record))
      expect(doc.at_css(".replacement-card.is-expanded")).to be_present
    end

    it "collapses non-pending replacements" do
      doc = render_card(create(:approved_post_replacement, post: post_record))
      expect(doc.at_css(".replacement-card.is-expanded")).to be_nil
    end

    it "honours an explicit expanded override" do
      doc = render_card(create(:approved_post_replacement, post: post_record), expanded: true)
      expect(doc.at_css(".replacement-card.is-expanded")).to be_present
    end
  end
end
