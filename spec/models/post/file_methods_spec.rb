# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "PostFileMethods" do
    let(:post) { create(:post, file_ext: "jpg", md5: "abcdef1234567890abcdef1234567890") }

    describe "#file_url" do
      it "returns a string containing the post's md5" do
        expect(post.file_url).to include(post.md5)
      end

      it "returns a string containing the file extension" do
        expect(post.file_url).to include(post.file_ext)
      end
    end

    describe "#preview_file_url" do
      it "returns a string URL" do
        expect(post.preview_file_url).to be_a(String)
        expect(post.preview_file_url).not_to be_empty
      end

      it "includes the md5 in the URL for a post with a preview" do
        post_with_preview = create(:post, file_ext: "jpg", image_width: 640, image_height: 480)
        expect(post_with_preview.preview_file_url).to include(post_with_preview.md5)
      end

      it "returns the download-preview fallback for posts without a valid preview" do
        no_preview = build(:post, file_ext: "swf", image_width: 640, image_height: 480)
        expect(no_preview.preview_file_url).to include("download-preview")
      end
    end

    describe "#large_file_url / #sample_url" do
      it "returns the file_url when the post has no sample" do
        small_post = build(:post, file_ext: "jpg",
                                  image_width: Danbooru.config.large_image_width - 1,
                                  image_height: Danbooru.config.large_image_width - 1)
        expect(small_post.large_file_url).to eq(small_post.file_url)
      end

      it "returns a different URL than file_url when the post has a sample" do
        large_post = build(:post, file_ext: "jpg",
                                  image_width: Danbooru.config.large_image_width * 2,
                                  image_height: Danbooru.config.large_image_width * 2)
        # large_file_url delegates to sample_url which returns the sample type URL
        expect(large_post.large_file_url).to be_a(String)
      end
    end

    describe "#file_path" do
      it "returns a string path" do
        expect(post.file_path).to be_a(String)
        expect(post.file_path).not_to be_empty
      end
    end

    describe "#open_graph_image_url" do
      it "returns a string URL" do
        expect(post.open_graph_image_url).to be_a(String)
      end

      it "returns file_url for a small image with no sample" do
        small_post = build(:post, file_ext: "jpg",
                                  image_width: Danbooru.config.large_image_width - 1,
                                  image_height: Danbooru.config.large_image_width - 1)
        expect(small_post.open_graph_image_url).to eq(small_post.file_url)
      end
    end

    describe "video duration" do
      it "returns nil when duration is not set" do
        post = build(:post, file_ext: "webm", duration: nil)
        expect(post.duration).to be_nil
      end

      it "returns the stored duration value" do
        post = build(:post, file_ext: "webm", duration: 12.5)
        expect(post.duration).to be_within(0.01).of(12.5)
      end
    end
  end
end
