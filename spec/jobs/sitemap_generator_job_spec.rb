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

    context "with an e926 profile" do
      include_context "with e926 site profile"

      def xml_for(hostname)
        ActiveSupport::Gzip.decompress(written.fetch("sitemap:#{hostname}:sitemap.xml.gz"))
      end

      it "generates the primary sitemap and queues one job per profile" do
        expect { described_class.new.perform }.to enqueue_sidekiq_job(described_class).with("e926")
        expect(written.keys).to eq(["sitemap:#{Danbooru.config.hostname}:sitemap.xml.gz"])
      end

      it "generates the e926 sitemap as e926" do
        safe_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "s") }
        explicit_post = CurrentUser.scoped(create(:user)) { create(:post, rating: "e") }
        allow(PostSets::Popular).to receive(:new).and_wrap_original do |original, *args|
          set = original.call(*args)
          # Popular reads safe mode itself; record what it would have filtered
          allow(set).to receive(:posts) { Post.where(id: [safe_post.id, explicit_post.id]).then { |q| CurrentUser.safe_mode? ? q.where(rating: "s") : q } }
          set
        end

        expect { described_class.new.perform("e926") }.not_to enqueue_sidekiq_job(described_class)

        xml = xml_for("e926.net")
        expect(xml).to include("https://e926.net/static/site_map")
        expect(xml).to include("/posts/#{safe_post.id}").and include("static1.e926.net")
        expect(xml).not_to include("/posts/#{explicit_post.id}")
        expect(CurrentSite.id).to eq("e621")
      end

      it "skips an unknown site" do
        described_class.new.perform("bogus")
        expect(written).to be_empty
      end
    end
  end
end
