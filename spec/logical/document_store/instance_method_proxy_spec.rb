# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentStore::InstanceMethodProxy do
  include_context "as admin"

  describe "#update_index" do
    subject(:update_index) { post.document_store.update_index }

    # Created before the client is stubbed so the double only ever sees the
    # explicit write below, not the one the create callback performs.
    let!(:post) { create(:post) }
    let(:client) { instance_double(OpenSearch::Client, index: true) }

    before { allow(Post.document_store).to receive(:client).and_return(client) }

    context "when the record exposes an index version" do
      before { allow(post).to receive(:index_version).and_return(12_345) }

      it "stamps the write with an external version so a stale write cannot win" do
        update_index
        expect(client).to have_received(:index).with(hash_including(version: 12_345, version_type: "external_gte"))
      end

      it "tolerates the resulting conflict rather than raising" do
        update_index
        expect(client).to have_received(:index).with(hash_including(ignore: 409))
      end
    end

    context "when the record has no index version" do
      it "sends no version metadata" do
        update_index
        expect(client).to have_received(:index).with(hash_excluding(:version, :version_type, :ignore))
      end
    end
  end
end
