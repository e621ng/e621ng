# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           PostSet Factory                                   #
# --------------------------------------------------------------------------- #

RSpec.describe PostSet do
  include_context "as member"

  describe "factory" do
    it "produces a valid post_set with build" do
      set = build(:post_set)
      expect(set).to be_valid, set.errors.full_messages.join(", ")
    end

    it "produces a valid post_set with create" do
      set = create(:post_set)
      expect(set).to be_persisted
    end

    it "produces a valid public_post_set" do
      set = create(:public_post_set)
      expect(set).to be_persisted
      expect(set.is_public).to be true
    end
  end
end
