# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                        ForumTopic Normalizations                            #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as member"

  # -------------------------------------------------------------------------
  # initialize_is_hidden (before_validation, on: :create)
  # -------------------------------------------------------------------------
  describe "initialize_is_hidden" do
    it "defaults is_hidden to false when not provided" do
      topic = create(:forum_topic)
      expect(topic.is_hidden).to be false
    end

    it "preserves is_hidden on update" do
      topic = create(:forum_topic)
      topic.update_columns(is_hidden: true)
      topic.update!(title: "Updated title")
      expect(topic.reload.is_hidden).to be true
    end
  end
end
