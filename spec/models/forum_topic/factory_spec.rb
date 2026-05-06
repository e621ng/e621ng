# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Factory sanity checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe ForumTopic do
  include_context "as member"

  describe "factory" do
    it "produces a valid forum_topic" do
      expect(create(:forum_topic)).to be_persisted
    end
  end
end
