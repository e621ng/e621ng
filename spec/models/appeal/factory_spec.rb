# frozen_string_literal: true

require "rails_helper"

RSpec.describe Appeal do
  include_context "as member"

  describe "factory" do
    it "creates a valid, persisted appeal" do
      expect(create(:appeal)).to be_persisted
    end

    it "defaults qtype to flag" do
      expect(create(:appeal).qtype).to eq("flag")
    end

    it "defaults status to pending" do
      expect(create(:appeal).status).to eq("pending")
    end

    it "sets creator_id from CurrentUser" do
      appeal = create(:appeal)
      expect(appeal.creator_id).to eq(CurrentUser.id)
    end

    it "sets accused_id to the PostFlag creator" do
      appeal = create(:appeal)
      expect(appeal.accused_id).to eq(appeal.content.creator_id)
    end
  end
end
