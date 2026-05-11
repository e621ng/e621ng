# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkIndexUpdateJob do
  subject(:job) { described_class }

  include_context "as member"

  describe "#perform" do
    it "re-indexes the specified records via import" do
      posts = create_list(:post, 3)
      ids   = posts.map(&:id)
      allow(Post.document_store).to receive(:import)
      job.perform_now("Post", ids)
      expect(Post.document_store).to have_received(:import).with(query: { id: ids })
    end

    it "does not raise when the id list is empty" do
      allow(Post.document_store).to receive(:import)
      expect { job.perform_now("Post", []) }.not_to raise_error
    end
  end
end
