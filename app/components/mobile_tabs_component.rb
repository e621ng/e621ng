# frozen_string_literal: true

# Tab row that splits a page into panels on mobile; on desktop the row is hidden and every panel shows.
# Panels are marked up with `MobileTabsComponent.panel_attributes`. Behavior lives in components/MobileTabs.ts.
class MobileTabsComponent < ViewComponent::Base
  Tab = Struct.new(:key, :label, :panel, keyword_init: true)

  # tabs: [{ key:, label:, panel: }] where panel is the id of the element the tab shows
  def initialize(tabs:, active:, id: nil, html_class: nil)
    super()
    @tabs = tabs.map { |tab| Tab.new(**tab) }
    @active = active.to_s
    @id = id
    @html_class = html_class
  end

  def self.panel_attributes(id:, active:)
    { id: id, data: { mobile_tab_panel: true, active: active ? true : nil } }
  end

  def render?
    tabs.size > 1
  end

  private

  attr_reader :tabs, :active, :id, :html_class

  def active?(tab)
    tab.key.to_s == active
  end
end
