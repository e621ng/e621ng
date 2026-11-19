# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/populate")

RSpec.describe Populate::WikiPages, :populate_exports do
  include_context "as admin"

  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  it "imports wiki pages with stub users" do
    create(:wiki_page, title: "scalie")
    page = create(:wiki_page, title: "dragon", body: "Big lizard.", parent: "scalie")
    page.update_columns(creator_id: 777_777, updater_id: 777_779)
    write_export("wiki_pages", dir)
    WikiPage.delete_all

    expect { expect(described_class.new(dir: dir).call).to eq(2) }.to output(/wiki pages: 2 inserted/).to_stdout

    expect(WikiPage.find(page.id)).to have_attributes(title: "dragon", body: "Big lizard.", parent: "scalie", creator_id: 777_777, updater_id: 777_779)
    expect(User.where(id: [777_777, 777_779]).count).to eq(2)
    expect { expect(described_class.new(dir: dir).call).to eq(0) }.to output.to_stdout
  end
end
