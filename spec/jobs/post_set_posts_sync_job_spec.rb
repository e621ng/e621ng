# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSetPostsSyncJob do
  describe "#perform" do
    context "when the set exists" do
      let(:post_set) { create(:post_set) }

      it "calls sync_posts_for_delta on the set" do
        allow(PostSet).to receive(:find).with(post_set.id).and_return(post_set)
        allow(post_set).to receive(:sync_posts_for_delta)
        described_class.perform_now(post_set.id, added_ids: [1], removed_ids: [2])
        expect(post_set).to have_received(:sync_posts_for_delta).with(added_ids: [1], removed_ids: [2])
      end
    end

    context "when the set does not exist" do
      it "does not raise an error" do
        expect { described_class.perform_now(-1) }.not_to raise_error
      end
    end
  end
end
