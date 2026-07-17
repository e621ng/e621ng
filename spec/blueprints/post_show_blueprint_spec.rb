# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostShowBlueprint do
  subject(:result) { described_class.render_as_hash(post) }

  include_context "as member"

  # 640x480 is below large_image_width (850), so it has no sample.
  let(:post) { create(:post) }
  # Large enough (min dimension > 850) that has_sample? is true.
  let(:sampled_post) { create(:post, image_width: 2000, image_height: 2000) }

  it "includes the expected top-level keys" do
    expect(result.keys).to match_array(%i[
      id created_at updated_at fav_count comment_count change_seq uploader_id
      description flags score relationships pools file sample sources tags
      locked_tags is_favorited vote initial_size
    ])
  end

  it "serializes basic attributes" do
    expect(result).to include(id: post.id, uploader_id: post.uploader_id, vote: post.vote_by)
  end

  describe "flags / score / relationships" do
    it "nests the flag booleans" do
      expect(result[:flags].keys).to match_array(%i[pending flagged note_locked status_locked rating_locked deleted has_notes])
    end

    it "nests the score" do
      expect(result[:score]).to eq(up: post.up_score, down: post.down_score, total: post.score)
    end

    it "always sends an empty children array" do
      expect(result[:relationships][:children]).to eq([])
    end
  end

  describe "file field" do
    it "exposes the file url for a visible post" do
      expect(result[:file]).to include(width: post.image_width, height: post.image_height, ext: post.file_ext, md5: post.md5)
      expect(result[:file][:url]).to eq(post.file_url)
    end

    context "when the post is not visible" do
      let(:post) { create(:deleted_post) }

      it "nils the file url" do
        expect(post).not_to be_visible
        expect(result[:file][:url]).to be_nil
      end
    end
  end

  describe "sample field" do
    context "with a sample (large image) and WebP enabled" do
      let(:post) { sampled_post }

      it "reports has: true and both jpg and webp urls" do
        expect(result[:sample][:has]).to be true
        expect(result[:sample][:url]).to eq(post.sample_url(:sample_jpg))
        expect(result[:sample][:webp_url]).to eq(post.sample_url(:sample_webp))
      end
    end

    context "with a sample but WebP disabled" do
      let(:post) { sampled_post }

      before { allow(Danbooru.config.custom_configuration).to receive(:webp_previews_enabled?).and_return(false) }

      it "nils webp_url" do
        expect(result[:sample][:webp_url]).to be_nil
      end
    end

    context "without a sample" do
      it "nils webp_url" do
        expect(result[:sample][:has]).to be false
        expect(result[:sample][:webp_url]).to be_nil
      end
    end

    context "for a video" do
      let(:post) { create(:post, file_ext: "webm") }

      it "carries the video_sample_list as alternates" do
        expect(result[:sample][:alternates]).to eq(post.video_sample_list)
      end

      it "has no image webp alternate" do
        expect(result[:sample][:webp_url]).to be_nil
      end
    end

    context "for an image" do
      it "has an empty alternates object" do
        expect(result[:sample][:alternates]).to eq({})
      end
    end
  end

  describe "sources field" do
    let(:post) { create(:post, source: "https://example.com/a\nhttps://example.com/b") }

    it "splits on real newlines" do
      expect(result[:sources]).to eq(%w[https://example.com/a https://example.com/b])
    end
  end

  describe "tags field" do
    it "is a flat array of tag names" do
      expect(result[:tags]).to match_array(post.tag_string.split)
    end
  end

  describe "initial_size field" do
    it "reflects the presenter's initial size for the current user" do
      expect(result[:initial_size]).to eq(post.presenter.initial_size(CurrentUser.user))
    end
  end
end
