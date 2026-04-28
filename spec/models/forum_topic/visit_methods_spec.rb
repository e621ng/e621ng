# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       ForumTopic Visit Methods                              #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as member"

  let(:visitor) { create(:user) }
  let(:topic)   { create(:forum_topic) }

  # -------------------------------------------------------------------------
  # #read_by?
  # -------------------------------------------------------------------------
  describe "#read_by?" do
    it "returns true when topic.updated_at is on or before user.last_forum_read_at" do
      topic.update_columns(updated_at: 1.hour.ago)
      visitor.update_columns(last_forum_read_at: Time.now)

      expect(topic.read_by?(visitor)).to be true
    end

    it "returns true when a ForumTopicVisit exists with last_read_at >= topic.updated_at" do
      topic.update_columns(updated_at: 1.hour.ago)
      visitor.update_columns(last_forum_read_at: nil)
      ForumTopicVisit.create!(user: visitor, forum_topic: topic, last_read_at: Time.now)
      # Reset memoized @topic_views by reloading the visitor
      visitor.reload

      expect(topic.read_by?(visitor)).to be true
    end

    it "returns false when neither condition holds" do
      topic.update_columns(updated_at: Time.now)
      visitor.update_columns(last_forum_read_at: nil)
      # No ForumTopicVisit exists

      expect(topic.read_by?(visitor)).to be false
    end
  end

  # -------------------------------------------------------------------------
  # #mark_as_read!
  # -------------------------------------------------------------------------
  describe "#mark_as_read!" do
    # Stub prune! so visit records survive the call for assertion purposes.
    # mark_as_read! deletes all visits via ForumTopicVisit.prune!(user) whenever
    # there are no remaining unread topics — which is always true in isolation.
    before { allow(ForumTopicVisit).to receive(:prune!) }

    it "creates a ForumTopicVisit on first call" do
      expect do
        topic.mark_as_read!(visitor)
      end.to change(ForumTopicVisit, :count).by(1)
    end

    it "updates last_read_at on subsequent calls without creating duplicates" do
      topic.mark_as_read!(visitor)
      first_visit = ForumTopicVisit.find_by!(user: visitor, forum_topic: topic)
      original_read_at = first_visit.last_read_at

      topic.update_columns(updated_at: 1.hour.from_now)
      topic.reload
      topic.mark_as_read!(visitor)

      expect(ForumTopicVisit.where(user: visitor, forum_topic: topic).count).to eq(1)
      expect(first_visit.reload.last_read_at).to be > original_read_at
    end

    it "does nothing for an anonymous user" do
      anonymous = User.anonymous
      expect do
        topic.mark_as_read!(anonymous)
      end.not_to change(ForumTopicVisit, :count)
    end
  end
end
