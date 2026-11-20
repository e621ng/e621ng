# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagUpdateRelatedJob do
  describe "#perform" do
    let(:tag) { create(:tag) }

    it "calls update_related on the tag" do
      allow(Tag).to receive(:find_by).with(id: tag.id).and_return(tag)
      allow(tag).to receive(:update_related)
      described_class.new.perform(tag.id)
      expect(tag).to have_received(:update_related)
    end

    it "does nothing when the tag no longer exists" do
      expect { described_class.new.perform(-1) }.not_to raise_error
    end
  end

  describe "sidekiq options" do
    it "holds a unique lock per tag until executed" do
      expect(described_class.get_sidekiq_options).to include("lock" => :until_executed, "retry" => 3)
    end
  end
end
