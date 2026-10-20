# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentStore::Model do
  include_context "as admin"

  let(:rejected) { OpenSearch::Transport::Transport::Errors::TooManyRequests.new("cluster_block_exception") }
  let(:client) { instance_double(OpenSearch::Client) }

  before { allow(Post.document_store).to receive(:client).and_return(client) }

  describe "after create" do
    context "when the index write is rejected with 429" do
      before { allow(client).to receive(:index).and_raise(rejected) }

      it "still creates the record" do
        expect { create(:post) }.to change(Post, :count).by(1)
      end

      it "retries the write later via IndexUpdateJob" do
        post = create(:post)
        expect(IndexUpdateJob).to have_enqueued_sidekiq_job("Post", post.id).in(DocumentStore::DEFERRED_WRITE_DELAY)
      end
    end

    context "when the index write fails for another reason" do
      before { allow(client).to receive(:index).and_raise(OpenSearch::Transport::Transport::Errors::InternalServerError) }

      it "raises" do
        expect { create(:post) }.to raise_error(OpenSearch::Transport::Transport::Errors::InternalServerError)
      end
    end
  end

  describe "after destroy" do
    let!(:post) do
      allow(client).to receive(:index).and_return({ "result" => "created" })
      create(:post)
    end

    context "when the index delete is rejected with 429" do
      before { allow(client).to receive(:delete).and_raise(rejected) }

      it "still destroys the record" do
        expect { post.destroy! }.to change(Post, :count).by(-1)
      end

      it "retries the delete later via IndexDeleteJob" do
        post.destroy!
        expect(IndexDeleteJob).to have_enqueued_sidekiq_job("Post", post.id).in(DocumentStore::DEFERRED_WRITE_DELAY)
      end
    end

    context "when the index write fails for another reason" do
      before { allow(client).to receive(:delete).and_raise(OpenSearch::Transport::Transport::Errors::InternalServerError) }

      it "raises" do
        expect { post.destroy! }.to raise_error(OpenSearch::Transport::Transport::Errors::InternalServerError)
      end
    end
  end
end
