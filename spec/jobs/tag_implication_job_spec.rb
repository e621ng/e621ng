# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagImplicationJob do
  include_context "as admin"

  describe "#perform" do
    let(:tag_implication) { create(:tag_implication) }

    it "calls process! on the tag implication" do
      allow(TagImplication).to receive(:find).with(tag_implication.id).and_return(tag_implication)
      allow(tag_implication).to receive(:process!)
      described_class.perform_now(tag_implication.id, false)
      expect(tag_implication).to have_received(:process!).with(update_topic: false)
    end
  end
end
