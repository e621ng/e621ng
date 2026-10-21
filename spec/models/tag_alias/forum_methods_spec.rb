# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagAlias do
  include_context "as admin"

  # ---------------------------------------------------------------------------
  # ForumMethods module
  # ---------------------------------------------------------------------------

  describe "#forum_updater" do
    it "returns a ForumUpdater" do
      ta = create(:tag_alias)
      expect(ta.forum_updater).to be_a(ForumUpdater)
    end

    it "looks up the forum post by body when forum_post is nil but forum_topic exists" do
      topic = create(:forum_topic)
      ta = create(:tag_alias, forum_topic: topic)
      expect(ta.forum_updater).to be_a(ForumUpdater)
    end
  end

  describe "forum updates" do
    let(:ta) { create(:tag_alias) }
    let(:topic) do
      create(:forum_topic, title: TagAliasRequest.topic_title(ta.antecedent_name, ta.consequent_name)).tap do |t|
        ta.update_columns(forum_topic_id: t.id)
        t.update_columns(last_bumped_at: 1.day.ago)
      end
    end

    it "does not bump the topic when rejected" do
      topic
      expect { ta.reject! }.to change { topic.reload.response_count }.by(1)
      expect(topic.last_bumped_at).to be < 1.hour.ago
      expect(topic.title).to start_with("[REJECTED]")
    end
  end
end
