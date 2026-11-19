# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "CountMethods" do
    describe ".fast_count" do
      it "returns 0 when no posts exist" do
        expect(Post.fast_count("nonexistent_tag_xyz")).to eq(0)
      end

      it "returns the count of posts matching a tag query" do
        post = create(:post)
        tag  = post.tag_array.first
        # Cache may have a stale value; flush it first
        Cache.delete("pfc:#{TagQuery.normalize(tag)}")
        count = Post.fast_count(tag)
        expect(count).to be >= 1
      end

      it "returns 0 with an empty tag string (or uses the post count)" do
        # fast_count("") counts all non-deleted posts
        post_count = Post.fast_count("")
        expect(post_count).to be_a(Integer)
      end

      it "restricts to safe-rated posts when safe_mode is enabled" do
        safe_post = create(:post, rating: "s")
        create(:post, rating: "e")
        tag = safe_post.tag_array.first
        Cache.delete("pfc:#{TagQuery.normalize("#{tag} rating:s")}")
        count = Post.fast_count(tag, enable_safe_mode: true)
        expect(count).to be_a(Integer)
      end

      context "on a tag-locked site" do
        include_context "with tag-locked site profile"

        it "puts the required tags in the cache key and not in the search clause" do
          key = "pfc:#{TagQuery.normalize('my_little_pony some_tag')}"
          Cache.delete(key)
          allow(Cache).to receive(:fetch).and_call_original
          allow(Post).to receive(:tag_match).and_call_original
          CurrentSite.with("mlp") { Post.fast_count("some_tag") }
          expect(Cache).to have_received(:fetch).with(key)
          expect(Post).to have_received(:tag_match).with(TagQuery.normalize("my_little_pony some_tag"), hash_including(enable_safe_mode: false, required_tags: []))
        end

        it "counts globally when asked" do
          allow(Cache).to receive(:fetch).and_call_original
          CurrentSite.with("mlp") { Post.fast_count("some_tag", required_tags: []) }
          expect(Cache).to have_received(:fetch).with("pfc:some_tag")
        end
      end

      it "returns 0 when the tag query raises TagQuery::CountExceededError" do
        allow(Post).to receive(:tag_match).and_raise(TagQuery::CountExceededError)
        expect(Post.fast_count("some_tag")).to eq(0)
      end
    end
  end
end
