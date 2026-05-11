# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagPostCountJob do
  describe "#perform" do
    let(:tag) { create(:tag) }

    it "calls fix_post_count on the tag" do
      allow(Tag).to receive(:find).with(tag.id).and_return(tag)
      allow(tag).to receive(:fix_post_count)
      described_class.perform_now(tag.id)
      expect(tag).to have_received(:fix_post_count)
    end
  end
end
