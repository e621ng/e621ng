# frozen_string_literal: true

require "rails_helper"

RSpec.describe ForumUpdater do
  include_context "as admin"

  let(:topic) { create(:forum_topic, title: "some request") }

  before { topic.update_columns(last_bumped_at: 1.day.ago) }

  describe "#update" do
    it "posts a response without bumping the topic" do
      updater = described_class.new(topic)
      expect { updater.update("approved") }.to change { topic.posts.count }.by(1)
      expect(topic.reload.last_bumped_at).to be < 1.hour.ago
    end

    it "updates the title without bumping the topic" do
      updater = described_class.new(topic, expected_title: "some request")
      updater.update("approved", "APPROVED")
      expect(topic.reload.title).to eq("[APPROVED] some request")
      expect(topic.last_bumped_at).to be < 1.hour.ago
    end

    it "edits the request post without bumping the topic" do
      updater = described_class.new(topic, forum_post: topic.original_post)
      updater.update("approved")
      expect(topic.original_post.reload.body).to end_with("EDIT: approved")
      expect(topic.reload.last_bumped_at).to be < 1.hour.ago
    end
  end
end
