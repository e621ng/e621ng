# frozen_string_literal: true

require "rails_helper"

RSpec.describe TagBatchFinalizeJob do
  include_context "as admin"

  let(:tag_query) { ["string_to_array(tag_string, ' ') @> ARRAY[?]::text[]", "new_tag"] }

  before { allow(Post.document_store).to receive(:import) }

  describe "#perform" do
    it "reindexes every post carrying the consequent" do
      described_class.perform_now("new_tag")
      expect(Post.document_store).to have_received(:import).with(query: tag_query)
    end

    it "also reindexes stragglers, which the consequent query cannot reach" do
      described_class.perform_now("new_tag", [101, 102])
      expect(Post.document_store).to have_received(:import).with(query: { id: [101, 102] })
    end

    it "issues no id import when there are no stragglers" do
      described_class.perform_now("new_tag", [])
      expect(Post.document_store).not_to have_received(:import).with(query: hash_including(:id))
    end
  end
end
