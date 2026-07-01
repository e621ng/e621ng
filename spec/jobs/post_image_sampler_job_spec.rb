# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostImageSamplerJob do
  include_context "as admin"

  describe "#perform" do
    let(:post) { create(:post) }

    it "calls ImageSampler.generate_post_images with the post" do
      allow(ImageSampler).to receive(:generate_post_images)
      described_class.perform_now(post.id)
      expect(ImageSampler).to have_received(:generate_post_images).with(post).at_least(:once)
    end
  end
end
