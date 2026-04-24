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

    describe "Post.delete_files class method" do
      it "raises DeletionError when another post with the same md5 still exists and force is false" do
        post = create(:post)
        expect do
          Post.delete_files(post.id + 1000, post.md5, post.file_ext, force: false)
        end.to raise_error(Post::DeletionError, /Files still in use/)
      end
    end

    describe "#file(type)" do
      it "delegates to storage_manager.open_file" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.file(:preview_jpg)
        expect(storage).to have_received(:open_file).with(post, :preview_jpg)
      end
    end

    describe "#tagged_large_file_url" do
      it "delegates to storage_manager.post_file_url with :sample type" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.tagged_large_file_url
        expect(storage).to have_received(:post_file_url).with(post, :sample)
      end
    end

    describe "#file_url_ext" do
      it "delegates to storage_manager.post_file_url with an ext option" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.file_url_ext("png")
        expect(storage).to have_received(:post_file_url).with(post, ext: "png")
      end
    end

    describe "#scaled_url_ext" do
      it "delegates to storage_manager.post_file_url with scale and ext options" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.scaled_url_ext("720p", "mp4")
        expect(storage).to have_received(:post_file_url).with(post, :scaled, ext: "mp4", scale: "720p")
      end
    end

    describe "#large_file_path" do
      it "delegates to storage_manager.post_file_path with :large type" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.large_file_path
        expect(storage).to have_received(:post_file_path).with(post, :large)
      end
    end

    describe "#preview_file_path" do
      it "delegates to storage_manager.post_file_path with preview type" do
        post = create(:post)
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.preview_file_path(:preview_webp)
        expect(storage).to have_received(:post_file_path).with(post, :preview_webp)
      end
    end

    describe "#open_graph_video_url" do
      let(:video_post) { build(:post, file_ext: "webm", image_width: 640, image_height: 480) }

      it "returns file_url when video_sample_list is blank" do
        allow(video_post).to receive(:video_sample_list).and_return({})
        expect(video_post.open_graph_video_url).to eq(video_post.file_url)
      end

      it "returns the last variant url when samples are blank but variants exist" do
        allow(video_post).to receive(:video_sample_list).and_return({
          samples: {},
          variants: { "webm" => { url: "https://example.com/alt.webm" } },
        })
        expect(video_post.open_graph_video_url).to eq("https://example.com/alt.webm")
      end

      it "returns the last sample url when samples exist" do
        allow(video_post).to receive(:video_sample_list).and_return({
          samples: { "720p" => { url: "https://example.com/720p.mp4" } },
          variants: {},
        })
        expect(video_post.open_graph_video_url).to eq("https://example.com/720p.mp4")
      end
    end

    describe "#has_sample_size?" do
      it "returns false when video_sample_list is blank" do
        post = build(:post, file_ext: "webm")
        allow(post).to receive(:video_sample_list).and_return({})
        expect(post.has_sample_size?("720p")).to be false
      end

      it "returns false when samples hash is blank" do
        post = build(:post, file_ext: "webm")
        allow(post).to receive(:video_sample_list).and_return({ samples: {} })
        expect(post.has_sample_size?("720p")).to be false
      end

      it "returns true when the scale key exists in samples" do
        post = build(:post, file_ext: "webm")
        allow(post).to receive(:video_sample_list).and_return({
          samples: { "720p" => { url: "https://example.com/720p.mp4" } },
        })
        expect(post.has_sample_size?("720p")).to be true
      end
    end

    describe "#video_sample_list" do
      it "returns {} for non-video posts" do
        post = build(:post, file_ext: "jpg")
        expect(post.video_sample_list).to eq({})
      end

      it "populates original size data for a video post with no video_samples" do
        post = build(:post, file_ext: "webm", image_width: 1280, image_height: 720, file_size: 5_000_000)
        result = post.video_sample_list
        expect(result[:original][:width]).to eq(1280)
        expect(result[:original][:height]).to eq(720)
        expect(result[:original][:size]).to eq(5_000_000)
      end
    end

    describe "#scaled_sample_dimensions" do
      it "returns scaled dimensions that fit within the given box" do
        post = build(:post, image_width: 1600, image_height: 900)
        width, height = post.scaled_sample_dimensions([800, 600])
        expect(width).to be <= 800
        expect(height).to be <= 600
      end
    end

    describe "#generate_video_samples" do
      it "enqueues PostVideoConversionJob immediately when later is false" do
        post = create(:post, file_ext: "webm")
        expect { post.generate_video_samples(later: false) }
          .to have_enqueued_job(PostVideoConversionJob)
      end

      it "enqueues PostVideoConversionJob with a delay when later is true" do
        post = create(:post, file_ext: "webm")
        expect { post.generate_video_samples(later: true) }
          .to have_enqueued_job(PostVideoConversionJob)
      end
    end

    describe "#regenerate_video_samples!" do
      it "calls generate_video_samples with later: true" do
        post = create(:post, file_ext: "webm")
        allow(post).to receive(:generate_video_samples)
        post.regenerate_video_samples!
        expect(post).to have_received(:generate_video_samples).with(later: true)
      end
    end

    describe "#delete_video_samples!" do
      it "does nothing for non-video posts" do
        post = build(:post, file_ext: "jpg")
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.delete_video_samples!
        expect(storage).not_to have_received(:delete_video_samples)
      end

      it "calls storage_manager.delete_video_samples and resets video_samples column for video posts" do
        post = create(:post, file_ext: "webm")
        storage = instance_spy(StorageManager)
        allow(post).to receive(:storage_manager).and_return(storage)
        post.delete_video_samples!
        expect(storage).to have_received(:delete_video_samples).with(post.md5)
        expect(post.reload.video_samples).to include("variants" => {}, "samples" => {})
      end
    end

    describe "#regenerate_image_samples!" do
      it "calls generate_image_samples with later: true when file_size exceeds 10MB" do
        post = create(:post, file_size: 11.megabytes)
        allow(post).to receive(:generate_image_samples)
        post.regenerate_image_samples!
        expect(post).to have_received(:generate_image_samples).with(later: true)
      end

      it "calls generate_image_samples immediately when file_size is 10MB or less" do
        post = create(:post, file_size: 10.megabytes)
        allow(post).to receive(:generate_image_samples)
        post.regenerate_image_samples!
        expect(post).to have_received(:generate_image_samples).with(no_args)
      end
    end
  end
end
