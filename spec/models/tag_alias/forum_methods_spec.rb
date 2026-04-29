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
end
