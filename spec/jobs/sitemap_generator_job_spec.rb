# frozen_string_literal: true

require "rails_helper"

RSpec.describe SitemapGeneratorJob do
  describe "#perform" do
    # The job's only OpenSearch call is `Post.tag_match("inpool:true order:hot")`.
    # The `posts_test` index is shared across parallel workers, so a concurrent
    # index rebuild can leave the `hotness` field transiently unmapped, making the
    # `order:hot` sort fail with a `[400] ... in order to sort on` error. Stub
    # tag_match (as other specs do) to keep this test off the shared index.
    # Dev and test share Redis DB 0; stub the write to leave the dev sitemap alone.
    let(:written) { {} }

    before do
      allow(Post).to receive(:tag_match).and_return(Post.none)
      allow(Cache.redis).to receive(:set) { |key, value| written[key] = value }
    end

    it "generates the sitemap without error" do
      expect { described_class.new.perform }.not_to raise_error
    end

    it "stores the gzipped sitemap in Redis" do
      described_class.new.perform

      key = "sitemap:#{Danbooru.config.hostname}:sitemap.xml.gz"
      expect(written.keys).to eq([key])
      xml = ActiveSupport::Gzip.decompress(written[key])
      expect(xml).to include("<urlset").and include("/static/site_map")
    end

    it "does not write to public/" do
      expect { described_class.new.perform }.not_to(change { Rails.public_path.glob("sitemap*") })
    end
  end
end
