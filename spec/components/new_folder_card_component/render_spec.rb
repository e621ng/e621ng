# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewFolderCardComponent, type: :component do
  include_context "as member"

  it "reuses the real post-thumbnail shell: article.thumbnail, .thm-desc" do
    doc = render_inline(described_class.new)
    expect(doc.at_css("article.thumbnail.favorite-new-folder-card")).to be_present
    expect(doc.at_css("article.thumbnail > div.thm-desc.favorite-new-folder-card-desc")).to be_present
  end

  it "uses a real button, not a fake link, as the interactive square body" do
    doc = render_inline(described_class.new)
    trigger = doc.at_css("article.thumbnail > button.favorite-new-folder-card-link")
    expect(trigger).to be_present
    expect(trigger["type"]).to eq("button")
    expect(doc.at_css("article.thumbnail > a")).to be_nil
  end

  it "carries the id FavoriteFolderOverlay.ts listens on" do
    doc = render_inline(described_class.new)
    expect(doc.at_css("#favorite-folder-new-trigger")).to be_present
  end

  it "carries the current folder's id as data-parent-id, so a created folder is parented correctly" do
    doc = render_inline(described_class.new(current_folder_id: 42))
    expect(doc.at_css("#favorite-folder-new-trigger")["data-parent-id"]).to eq("42")
  end

  it "renders an empty data-parent-id at root (no current folder)" do
    doc = render_inline(described_class.new)
    expect(doc.at_css("#favorite-folder-new-trigger")["data-parent-id"]).to eq("")
  end

  it "renders the folder-plus icon large and centered in the square body" do
    doc = render_inline(described_class.new)
    icon = doc.at_css("button.favorite-new-folder-card-link svg[name='folder_plus']")
    expect(icon).to be_present
  end

  it "labels the footer New Folder, using the same thm-desc-a treatment as the folder name" do
    doc = render_inline(described_class.new)
    name_cell = doc.at_css(".favorite-new-folder-card-desc .thm-desc-a")
    expect(name_cell).to be_present
    expect(name_cell.text.strip).to eq("New Folder")
  end

  it "is never a drag source or drop target - no data-id, no data-drop-target, no data-folder-drag-source anywhere in the card" do
    doc = render_inline(described_class.new)
    card = doc.at_css("article.thumbnail")
    expect(card["data-id"]).to be_nil
    expect(card["data-drop-target"]).to be_nil
    expect(card["data-folder-drag-source"]).to be_nil
    expect(doc.at_css("[data-id]")).to be_nil
    expect(doc.at_css("[data-drop-target]")).to be_nil
    expect(doc.at_css("[data-folder-drag-source]")).to be_nil
  end

  it "has no rename or delete management actions (it is a trigger, not a folder card)" do
    doc = render_inline(described_class.new)
    expect(doc.at_css(".favorite-folder-rename-trigger")).to be_nil
    expect(doc.at_css(".favorite-folder-delete-trigger")).to be_nil
    expect(doc.at_css("form")).to be_nil
  end

  it "carries no inline grid-column/style of its own - relies entirely on the shared class-based sizing rule" do
    doc = render_inline(described_class.new)
    card = doc.at_css("article.thumbnail")
    expect(card["style"]).to be_nil
    trigger = doc.at_css("#favorite-folder-new-trigger")
    expect(trigger["style"]).to be_nil
    expect(trigger.classes).to include("favorite-new-folder-card-link")
  end
end
