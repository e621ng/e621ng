# frozen_string_literal: true

require "rails_helper"

RSpec.describe FolderCardComponent, type: :component do
  include_context "as member"

  let(:user) { create(:user) }
  let(:folder) { create(:favorite_folder, user: user, name: "Memes") }

  def component(folder = self.folder)
    described_class.new(folder: folder)
  end

  it "renders the folder name" do
    doc = render_inline(component)
    expect(doc.text).to include("Memes")
  end

  it "reuses the real post-thumbnail shell: article.thumbnail, a.thm-link, .thm-desc" do
    doc = render_inline(component)
    expect(doc.at_css("article.thumbnail.favorite-folder-card")).to be_present
    expect(doc.at_css("article.thumbnail > a.thm-link.favorite-folder-card-link")).to be_present
    expect(doc.at_css("article.thumbnail > div.thm-desc.favorite-folder-card-desc")).to be_present
  end

  it "links to the folder's Favorites listing" do
    doc = render_inline(component)
    expect(doc.at_css("a.thm-link")["href"]).to eq("/favorites?folder_id=#{folder.id}")
  end

  it "marks the outer article as a folder drop target with its folder id, and never as a real post" do
    doc = render_inline(component)
    card = doc.at_css("article.thumbnail")
    expect(card["data-drop-target"]).to eq("folder")
    expect(card["data-folder-id"]).to eq(folder.id.to_s)
    expect(card["data-id"]).to be_nil
    expect(doc.at_css("[data-id]")).to be_nil
  end

  it "marks the outer article as a folder drag source, in the folder namespace, not the post one" do
    doc = render_inline(component)
    card = doc.at_css("article.thumbnail")
    expect(card["data-folder-drag-source"]).to be_present
  end

  it "renders folder and folder-open icons" do
    doc = render_inline(component)
    expect(doc.at_css("svg.folder-icon-closed")).to be_present
    expect(doc.at_css("svg.folder-icon-open")).to be_present
  end

  it "renders rename and delete controls in the thm-desc-b action cells, as siblings of the navigation link, not nested inside it" do
    doc = render_inline(component)
    link = doc.at_css("a.thm-link")
    expect(link.at_css("button, form")).to be_nil
    expect(doc.at_css("button.thm-desc-b.favorite-folder-rename-trigger")).to be_present
    expect(doc.at_css("form.thm-desc-b")).to be_present
  end

  it "deletes immediately, with no confirmation prompt on the delete form or button" do
    doc = render_inline(component)
    form = doc.at_css("form.thm-desc-b")
    expect(form["data-confirm"]).to be_nil
    expect(form["data-turbo-confirm"]).to be_nil
    button = form.at_css("button.favorite-folder-delete-trigger")
    expect(button).to be_present
    expect(button["data-confirm"]).to be_nil
    expect(button["data-turbo-confirm"]).to be_nil
  end

  it "centers the folder name (thm-desc-a) between the rename and delete action cells (thm-desc-b) in the footer" do
    doc = render_inline(component)
    desc = doc.at_css(".favorite-folder-card-desc")
    children = desc.children.select(&:element?)
    expect(children.map(&:name)).to eq(%w[button span form])
    expect(children.map { |n| n.classes.include?("thm-desc-b") }).to eq([true, false, true])
    expect(children[1].classes).to include("thm-desc-a")
    expect(desc.at_css(".favorite-folder-card-name-text").text).to eq("Memes")
  end

  it "carries no inline grid-column/style of its own, and the name cell can shrink/truncate" do
    doc = render_inline(component)
    card = doc.at_css("article.thumbnail")
    expect(card["style"]).to be_nil
    expect(doc.at_css("a.thm-link")["style"]).to be_nil
    name_text = doc.at_css(".favorite-folder-card-name-text")
    expect(name_text.classes).to include("favorite-folder-card-name-text")
  end
end
