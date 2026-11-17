# frozen_string_literal: true

require "rails_helper"

RSpec.describe MobileTabsComponent, type: :component do
  let(:tabs) do
    [
      { key: "tags", label: "Tags", panel: "panel-tags" },
      { key: "comments", label: "Comments", panel: "panel-comments" },
    ]
  end

  def render_tabs(**)
    render_inline(described_class.new(tabs: tabs, active: "comments", **))
  end

  describe "rendered output" do
    it "renders a tablist with one tab per entry" do
      doc = render_tabs(id: "mobile-tabs", html_class: "tabs")
      list = doc.at_css("div.mobile-tabs.tabs#mobile-tabs[role=tablist]")
      expect(list).to be_present
      expect(list.css("button[role=tab]").map(&:text)).to eq(%w[Tags Comments])
    end

    it "links each tab to its panel" do
      doc = render_tabs
      expect(doc.at_css("button[data-tab=tags]")["aria-controls"]).to eq("panel-tags")
      expect(doc.at_css("button[data-tab=comments]")["aria-controls"]).to eq("panel-comments")
    end

    it "marks only the active tab as selected and focusable" do
      doc = render_tabs
      active = doc.at_css("button[data-tab=comments]")
      inactive = doc.at_css("button[data-tab=tags]")
      expect(active["aria-selected"]).to eq("true")
      expect(active["tabindex"]).to eq("0")
      expect(inactive["aria-selected"]).to eq("false")
      expect(inactive["tabindex"]).to eq("-1")
    end

    it "renders nothing with a single tab" do
      doc = render_inline(described_class.new(tabs: tabs.first(1), active: "tags"))
      expect(doc.to_html.strip).to be_empty
    end
  end

  describe ".panel_attributes" do
    it "marks the active panel" do
      expect(described_class.panel_attributes(id: "panel", active: true))
        .to eq(id: "panel", data: { mobile_tab_panel: true, active: true })
    end

    it "leaves the active flag out for inactive panels" do
      html = ApplicationController.helpers.tag.div(**described_class.panel_attributes(id: "panel", active: false))
      expect(html).to include("data-mobile-tab-panel")
      expect(html).not_to include("data-active")
    end
  end
end
