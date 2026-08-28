# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostPruneJob do
  describe "#perform" do
    it "prunes expired pending posts" do
      pruner = instance_double(PostPruner)
      allow(PostPruner).to receive(:new).and_return(pruner)
      allow(pruner).to receive(:prune!)

      described_class.new.perform

      expect(pruner).to have_received(:prune!)
    end
  end
end
