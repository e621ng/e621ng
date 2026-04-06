# frozen_string_literal: true

require "rails_helper"

RSpec.describe Post do
  include_context "as admin"

  describe "ImageMethods" do
    describe "#has_dimensions?" do
      it "returns true when both width and height are present" do
        post = build(:post, image_width: 640, image_height: 480)
        expect(post.has_dimensions?).to be true
      end

      it "returns false when width is nil" do
        post = build(:post, image_width: nil, image_height: 480)
        expect(post.has_dimensions?).to be false
      end

      it "returns false when height is nil" do
        post = build(:post, image_width: 640, image_height: nil)
        expect(post.has_dimensions?).to be false
      end
    end

    describe "#has_preview?" do
      it "returns true for an image with dimensions larger than 1x1" do
        post = build(:post, file_ext: "jpg", image_width: 640, image_height: 480)
        expect(post.has_preview?).to be true
      end

      it "returns false for a non-image, non-video file type" do
        post = build(:post, file_ext: "swf", image_width: 640, image_height: 480)
        expect(post.has_preview?).to be false
      end

      it "returns false for a 1x1 image (likely corrupt)" do
        post = build(:post, file_ext: "jpg", image_width: 1, image_height: 1)
        expect(post.has_preview?).to be false
      end

      it "returns true for a video with valid dimensions" do
        post = build(:post, file_ext: "webm", image_width: 1280, image_height: 720)
        expect(post.has_preview?).to be true
      end
    end

    describe "#has_sample?" do
      it "returns true for a video" do
        post = build(:post, file_ext: "webm", image_width: 1280, image_height: 720)
        expect(post.has_sample?).to be true
      end

      it "returns true for a large image that exceeds the sample threshold" do
        large_width = Danbooru.config.large_image_width + 1
        post = build(:post, file_ext: "jpg", image_width: large_width, image_height: large_width)
        expect(post.has_sample?).to be true
      end

      it "returns false for a small image that fits within the sample threshold" do
        small_width = Danbooru.config.large_image_width - 1
        post = build(:post, file_ext: "jpg", image_width: small_width, image_height: small_width)
        expect(post.has_sample?).to be false
      end

      it "returns false for a GIF" do
        post = build(:post, file_ext: "gif")
        expect(post.has_sample?).to be false
      end
    end

    describe "#twitter_card_supported?" do
      it "returns true for an image that meets the minimum dimensions" do
        post = build(:post, image_width: 280, image_height: 150)
        expect(post.twitter_card_supported?).to be true
      end

      it "returns false when width is too small" do
        post = build(:post, image_width: 100, image_height: 150)
        expect(post.twitter_card_supported?).to be false
      end

      it "returns false when height is too small" do
        post = build(:post, image_width: 280, image_height: 100)
        expect(post.twitter_card_supported?).to be false
      end
    end

    describe "#resize_percentage" do
      it "returns 100 when the post has no sample (sample equals original)" do
        small_width = Danbooru.config.large_image_width - 1
        post = build(:post, file_ext: "jpg", image_width: small_width, image_height: small_width)
        expect(post.resize_percentage).to be_within(0.1).of(100.0)
      end

      it "returns a value less than 100 when the post has a sample" do
        large_width = Danbooru.config.large_image_width * 2
        post = build(:post, file_ext: "jpg", image_width: large_width, image_height: large_width)
        expect(post.resize_percentage).to be < 100
      end
    end

    describe "is_* file type predicates" do
      it "recognizes jpg as an image" do
        expect(build(:post, file_ext: "jpg").is_image?).to be true
        expect(build(:post, file_ext: "jpg").is_jpg?).to be true
      end

      it "recognizes png as an image" do
        expect(build(:post, file_ext: "png").is_image?).to be true
        expect(build(:post, file_ext: "png").is_png?).to be true
      end

      it "recognizes gif as an image" do
        expect(build(:post, file_ext: "gif").is_image?).to be true
        expect(build(:post, file_ext: "gif").is_gif?).to be true
      end

      it "recognizes webm as a video" do
        expect(build(:post, file_ext: "webm").is_video?).to be true
        expect(build(:post, file_ext: "webm").is_webm?).to be true
      end

      it "recognizes mp4 as a video" do
        expect(build(:post, file_ext: "mp4").is_video?).to be true
        expect(build(:post, file_ext: "mp4").is_mp4?).to be true
      end

      it "recognizes swf as flash (not image, not video)" do
        post = build(:post, file_ext: "swf")
        expect(post.is_flash?).to be true
        expect(post.is_image?).to be false
        expect(post.is_video?).to be false
      end
    end
  end
end
