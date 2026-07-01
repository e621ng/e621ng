# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ForumPost Normalizations                             #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  include_context "as member"

  let(:topic) { create(:forum_topic) }

  # -------------------------------------------------------------------------
  # body — \r\n → \n
  # -------------------------------------------------------------------------
  describe "body normalization" do
    it "converts \\r\\n line endings to \\n on create" do
      post = create(:forum_post, topic_id: topic.id, body: "line one\r\nline two")
      expect(post.body).to eq("line one\nline two")
    end

    it "converts \\r\\n line endings to \\n on update" do
      post = create(:forum_post, topic_id: topic.id, body: "initial")
      post.update!(body: "updated\r\nbody")
      expect(post.body).to eq("updated\nbody")
    end
  end

  # -------------------------------------------------------------------------
  # is_hidden — initialized to false on create
  # -------------------------------------------------------------------------
  describe "is_hidden initialization" do
    it "sets is_hidden to false when not provided" do
      record = build(:forum_post, topic_id: topic.id)
      record.is_hidden = nil
      record.valid?
      expect(record.is_hidden).to be false
    end

    it "does not override an explicitly set is_hidden value" do
      record = build(:forum_post, topic_id: topic.id)
      record.is_hidden = true
      record.valid?
      expect(record.is_hidden).to be true
    end
  end
end
