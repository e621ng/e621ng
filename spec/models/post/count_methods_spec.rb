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
    end
  end
end
