# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumTopicRowComponent, type: :component do
  include_context "as member"

  let(:topic) { create(:forum_topic, title: "Row topic") }

  def render_row(pinned: false)
    render_inline(described_class.new(topic: topic, pinned: pinned))
  end

  it "links the title to the topic" do
    link = render_row.at_css("a.forum-topic-item-link")
    expect(link.text).to eq("Row topic")
    expect(link["href"]).to eq("/forum_topics/#{topic.id}")
  end

  it "shows the reply count without the original post" do
    topic.update_columns(response_count: 4)
    expect(render_row.at_css(".forum-topic-item-replies").text.strip).to eq("3")
  end

  it "marks unread topics" do
    expect(render_row.at_css(".forum-topic-item.unread")).to be_present
  end

  it "does not mark read topics" do
    CurrentUser.user.update_columns(last_forum_read_at: 1.minute.from_now)
    expect(render_row.at_css(".forum-topic-item.unread")).to be_nil
  end

  it "renders the pinned variant with a pin marker" do
    expect(render_row(pinned: true).at_css(".forum-topic-item.pinned svg[name='pin']")).to be_present
  end

  it "shows locked and hidden badges" do
    topic.update_columns(is_locked: true, is_hidden: true)
    expect(render_row.css(".forum-topic-badge").map(&:text)).to eq(%w[Locked Hidden])
  end

  it "links to the last page of long topics" do
    topic.update_columns(response_count: (Danbooru.config.records_per_page * 2) + 1)
    link = render_row.at_css("a.forum-topic-item-last-page")
    expect(link.text).to eq("page 3")
    expect(link["href"]).to eq("/forum_topics/#{topic.id}?page=3")
  end
end
