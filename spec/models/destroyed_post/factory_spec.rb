# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                       DestroyedPost Factory sanity                          #
# --------------------------------------------------------------------------- #

RSpec.describe DestroyedPost do
  describe "factory" do
    it "produces a valid destroyed post" do
      expect(create(:destroyed_post)).to be_persisted
    end

    it "sets a destroyer association" do
      dp = create(:destroyed_post)
      expect(dp.destroyer).to be_a(User)
    end

    it "leaves uploader nil by default" do
      dp = create(:destroyed_post)
      expect(dp.uploader).to be_nil
    end

    it "produces a valid destroyed post with uploader" do
      expect(create(:destroyed_post_with_uploader)).to be_persisted
    end

    it "sets an uploader association on the sub-factory" do
      dp = create(:destroyed_post_with_uploader)
      expect(dp.uploader).to be_a(User)
    end
  end
end
