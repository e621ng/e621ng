# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpdateTagCategoryJob do
  describe "#perform" do
    let(:tag) { create(:tag) }

    it "calls update_category_post_counts! on the tag" do
      allow(Tag).to receive(:find).with(tag.id).and_return(tag)
      allow(tag).to receive(:update_category_post_counts!)
      described_class.perform_now(tag.id)
      expect(tag).to have_received(:update_category_post_counts!)
    end
  end
end
