# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoUpCardComponent, type: :component do
  include_context "as member"

  it "reuses the real post-thumbnail shell: article.thumbnail, a.thm-link, .thm-desc" do
    doc = render_inline(described_class.new(parent_folder_id: nil))
    expect(doc.at_css("article.thumbnail.favorite-go-up-card")).to be_present
    expect(doc.at_css("article.thumbnail > a.thm-link.favorite-go-up-card-link")).to be_present
    expect(doc.at_css("article.thumbnail > div.thm-desc.favorite-go-up-card-desc")).to be_present
  end

  it "links to the parent folder's Favorites listing" do
    doc = render_inline(described_class.new(parent_folder_id: 42))
    expect(doc.at_css("a.thm-link")["href"]).to eq("/favorites?folder_id=42")
  end

  it "links to root when parent_folder_id is nil" do
    doc = render_inline(described_class.new(parent_folder_id: nil))
    expect(doc.at_css("a.thm-link")["href"]).to eq("/favorites")
  end

  it "marks the outer article as the go-up drop target with the destination folder id, and never as a real post" do
    doc = render_inline(described_class.new(parent_folder_id: 42))
    card = doc.at_css("article.thumbnail")
    expect(card["data-drop-target"]).to eq("go-up")
    expect(card["data-destination-folder-id"]).to eq("42")
    expect(card["data-id"]).to be_nil
    expect(doc.at_css("[data-id]")).to be_nil
  end

  it "renders the corner-up-left icon large and centered in the square body" do
    doc = render_inline(described_class.new(parent_folder_id: nil))
    expect(doc.at_css("a.thm-link svg")).to be_present
  end

  it "labels the footer Go Up, using the same thm-desc-a treatment as the folder name" do
    doc = render_inline(described_class.new(parent_folder_id: nil))
    name_cell = doc.at_css(".favorite-go-up-card-desc .thm-desc-a")
    expect(name_cell).to be_present
    expect(name_cell.text.strip).to eq("Go Up")
  end

  it "has no rename or delete management actions" do
    doc = render_inline(described_class.new(parent_folder_id: nil))
    expect(doc.at_css("button, form")).to be_nil
  end
end
