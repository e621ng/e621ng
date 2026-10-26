# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexDeleteJob do
  describe "#perform" do
    let(:client) { instance_double(OpenSearch::Client) }

    before { allow(Post.document_store).to receive(:client).and_return(client) }

    it "deletes the document by id, tolerating one that is already gone" do
      allow(client).to receive(:delete).and_return({ "result" => "deleted" })
      described_class.new.perform("Post", 123)
      expect(client).to have_received(:delete).with(hash_including(index: Post.document_store.index_name, id: 123, ignore: 404))
    end

    it "lets a 429 propagate so Sidekiq retries with backoff" do
      allow(client).to receive(:delete).and_raise(OpenSearch::Transport::Transport::Errors::TooManyRequests)
      expect { described_class.new.perform("Post", 123) }.to raise_error(OpenSearch::Transport::Transport::Errors::TooManyRequests)
    end
  end
end
