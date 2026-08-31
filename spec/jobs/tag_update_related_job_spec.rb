# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagUpdateRelatedJob do
  describe "#perform" do
    let(:tag) { create(:tag) }

    it "calls update_related on the tag" do
      allow(Tag).to receive(:find).with(tag.id).and_return(tag)
      allow(tag).to receive(:update_related)
      described_class.new.perform(tag.id)
      expect(tag).to have_received(:update_related)
    end
  end
end
