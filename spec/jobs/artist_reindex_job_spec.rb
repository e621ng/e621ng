# frozen_string_literal: true

require "rails_helper"

RSpec.describe ArtistReindexJob do
  include_context "as admin"

  let(:artist_name) { "reindex_artist" }
  let!(:tagged)   { create(:post, tag_string: "#{artist_name} extra") }
  let!(:untagged) { create(:post, tag_string: "unrelated") }

  it "reindexes every post tagged with the artist name" do
    reindexed = []
    allow_any_instance_of(Post).to receive(:update_index) { |post, **| reindexed << post.id } # rubocop:disable RSpec/AnyInstance
    described_class.perform_now(artist_name)
    expect(reindexed).to include(tagged.id)
    expect(reindexed).not_to include(untagged.id)
  end

  it "returns without error when no posts match" do
    expect { described_class.perform_now("no_such_artist") }.not_to raise_error
  end
end
