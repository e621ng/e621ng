# frozen_string_literal: true

require "rails_helper"

RSpec.describe SitemapGeneratorJob do
  describe "#perform" do
    # The job's only OpenSearch call is `Post.tag_match("inpool:true order:hot")`.
    # The `posts_test` index is shared across parallel workers, so a concurrent
    # index rebuild can leave the `hotness` field transiently unmapped, making the
    # `order:hot` sort fail with a `[400] ... in order to sort on` error. Stub
    # tag_match (as other specs do) to keep this test off the shared index.
    before { allow(Post).to receive(:tag_match).and_return(Post.none) }

    it "generates the sitemap without error" do
      expect { described_class.perform_now }.not_to raise_error
    end
  end
end
