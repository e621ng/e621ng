# frozen_string_literal: true

require "rails_helper"

# --------------------------------------------------------------------------- #
#                           Factory sanity checks                             #
# --------------------------------------------------------------------------- #

RSpec.describe Takedown do
  include_context "as admin"

  describe "factory" do
    it "produces a valid takedown" do
      expect(create(:takedown)).to be_persisted
    end

    it "produces a valid takedown_with_post" do
      post = create(:post)
      expect(create(:takedown_with_post, post: post)).to be_persisted
    end

    it "initializes status to pending" do
      expect(create(:takedown).status).to eq("pending")
    end

    it "initializes vericode to a non-blank value" do
      expect(create(:takedown).vericode).to be_present
    end

    it "initializes del_post_ids to empty string" do
      expect(create(:takedown).del_post_ids).to eq("")
    end
  end
end
