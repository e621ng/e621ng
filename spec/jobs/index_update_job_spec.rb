# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexUpdateJob do
  include_context "as admin"

  describe "#perform" do
    context "when the record exists" do
      let(:post) { create(:post) }
      let(:document_store) { instance_double(DocumentStore::InstanceMethodProxy, update_index: true) }

      it "calls update_index on the document store" do
        allow(Post).to receive(:find).with(post.id).and_return(post)
        allow(post).to receive(:document_store).and_return(document_store)
        described_class.perform_now("Post", post.id)
        expect(document_store).to have_received(:update_index)
      end
    end

    context "when the record does not exist" do
      it "does not raise an error" do
        expect { described_class.perform_now("Post", -1) }.not_to raise_error
      end
    end
  end
end
