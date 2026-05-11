# frozen_string_literal: true

require "rails_helper"

RSpec.describe IqdbUpdateJob do
  include_context "as admin"

  describe "#perform" do
    context "when the post exists" do
      let(:post) { create(:post) }

      it "calls IqdbProxy.update_post with the post" do
        allow(IqdbProxy).to receive(:update_post)
        described_class.perform_now(post.id)
        expect(IqdbProxy).to have_received(:update_post).with(post)
      end
    end

    context "when the post does not exist" do
      it "does not call IqdbProxy.update_post" do
        allow(IqdbProxy).to receive(:update_post)
        described_class.perform_now(-1)
        expect(IqdbProxy).not_to have_received(:update_post)
      end
    end
  end
end
