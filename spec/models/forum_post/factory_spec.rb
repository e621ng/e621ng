# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                         ForumPost Factory Sanity                            #
# --------------------------------------------------------------------------- #

RSpec.describe ForumPost do
  include_context "as member"

  describe "factory" do
    it "produces a valid forum_post" do
      expect(create(:forum_post)).to be_persisted
    end

    it "defaults is_hidden to false" do
      expect(create(:forum_post).is_hidden).to be false
    end

    it "defaults body to a non-blank string" do
      expect(create(:forum_post).body).to be_present
    end
  end
end
