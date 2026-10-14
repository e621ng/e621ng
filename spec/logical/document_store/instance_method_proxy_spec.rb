# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocumentStore::InstanceMethodProxy do
  include_context "as admin"

  describe "#update_index" do
    subject(:update_index) { post.document_store.update_index }

    # Created before the client is stubbed so the double only ever sees the
    # explicit write below, not the one the create callback performs.
    let!(:post) { create(:post) }
    let(:client) { instance_double(OpenSearch::Client, index: { "result" => "updated" }) }

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

      context "when the write is rejected" do
        let(:conflict) { { "status" => 409, "error" => { "type" => "version_conflict_engine_exception" } } }
        let(:success) { { "result" => "updated" } }
        let(:client) { instance_double(OpenSearch::Client, get: { "_version" => 23_456 }) }

        before { allow(Rails.logger).to receive(:warn) }

        context "when the document has moved ahead" do
          before { allow(client).to receive(:index).and_return(conflict, success) }

          it "rewrites the same content at the document's version" do
            update_index
            expect(client).to have_received(:index).with(hash_including(version: 23_456, version_type: "external_gte")).once
          end

          it "logs the retry, which the transport itself swallows" do
            update_index
            expect(Rails.logger).to have_received(:warn).with(/version conflict indexing .*#{post.id}/)
          end
        end

        context "when the document was deleted in the meantime" do
          before do
            allow(client).to receive(:get).and_return({ "found" => false })
            allow(client).to receive(:index).and_return(conflict, success)
          end

          it "retries at the record's own version" do
            update_index
            expect(client).to have_received(:index).with(hash_including(version: 12_345)).twice
          end
        end

        context "when the conflict persists" do
          before { allow(client).to receive(:index).and_return(conflict) }

          it "raises after bounded retries instead of dropping the update" do
            expect { update_index }.to raise_error(DocumentStore::VersionConflictError, /#{post.id}/)
          end

          it "stops writing after the retry budget" do
            begin
              update_index
            rescue DocumentStore::VersionConflictError
              nil
            end
            expect(client).to have_received(:index).exactly(3).times
          end
        end
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
