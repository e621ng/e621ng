# frozen_string_literal: true

require "rails_helper"

# Deletion flags stay in post_flags until they are removed; flag reads must not see them.
RSpec.describe PostFlag do
  include_context "as admin"

  let(:post) { create(:deleted_post) }
  let!(:legacy) { create(:legacy_deletion_post_flag, post: post) }

  it "is hidden from searches" do
    expect(described_class.search({})).not_to include(have_attributes(id: legacy.id))
    expect(described_class.unscoped.where(id: legacy.id)).to exist
  end

  it "is hidden from the post's flags and pending flag" do
    expect(post.flags).to be_empty
    expect(post.pending_flag).to be_nil
  end

  it "is not indexed as the post's flag" do
    expect(post.as_indexed_json[:flagger]).to be_nil
  end

  it "is not indexed as the post's flag by a bulk import" do
    client = instance_double(OpenSearch::Client)
    allow(Post.document_store).to receive(:client).and_return(client)
    docs = []
    allow(client).to receive(:bulk) do |args|
      docs.concat(args[:body].map { |entry| entry[:index][:data] })
      { "errors" => false, "items" => [] }
    end

    Post.document_store.import(query: { id: post.id })
    expect(docs.sole[:flagger]).to be_blank
  end
end
