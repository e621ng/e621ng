# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager do
  let(:md5) { "abcdef1234567890abcdef1234567890" }
  let(:manager) do
    StorageManager::Local.new(base_url: "http://example.com", base_path: "/data", hierarchical: false)
  end

  # -------------------------------------------------------------------------
  # #root_url
  # -------------------------------------------------------------------------
  describe "#root_url" do
    it "returns the scheme+host when base_url is absolute" do
      expect(manager.root_url).to eq("http://example.com")
    end

    it "returns an empty string when base_url is relative" do
      relative_manager = StorageManager::Local.new(base_url: "/data")
      expect(relative_manager.root_url).to eq("")
    end
  end

  # -------------------------------------------------------------------------
  # #furids_url
  # -------------------------------------------------------------------------
  describe "#furids_url" do
    it "returns the furid directory URL" do
      expect(manager.furids_url).to eq("http://example.com/data/furid/")
    end
  end

  # -------------------------------------------------------------------------
  # #mascot_url
  # -------------------------------------------------------------------------
  describe "#mascot_url" do
    let(:mascot) { instance_double(Mascot, md5: md5, file_ext: "png") }

    it "returns the mascot file URL" do
      expect(manager.mascot_url(mascot)).to eq("http://example.com/data/mascots/#{md5}.png")
    end
  end

  # -------------------------------------------------------------------------
  # #file_url
  # -------------------------------------------------------------------------
  describe "#file_url" do
    context "without protection" do
      it "returns the full URL for :original type" do
        expect(manager.file_url(md5, "jpg", :original)).to eq("http://example.com/data/#{md5}.jpg")
      end

      it "returns the preview URL for :preview_jpg type" do
        expect(manager.file_url(md5, "jpg", :preview_jpg)).to eq("http://example.com/data/preview/#{md5}.jpg")
      end

      it "returns the sample URL for :sample_jpg type" do
        expect(manager.file_url(md5, "jpg", :sample_jpg)).to eq("http://example.com/data/sample/#{md5}.jpg")
      end
    end

    context "with protect: true" do
      include_context "as member"

      it "appends auth query params to the URL" do
        url = manager.file_url(md5, "jpg", :original, protect: true)
        expect(url).to match(%r{\Ahttp://example\.com/data/deleted/#{md5}\.jpg\?auth=.+&expires=\d+&uid=\d+\z})
      end

      it "includes the current user's id in the uid param" do
        url = manager.file_url(md5, "jpg", :original, protect: true)
        uid = url[/uid=(\d+)/, 1].to_i
        expect(uid).to eq(CurrentUser.id)
      end
    end
  end

  # -------------------------------------------------------------------------
  # #post_file_url
  # -------------------------------------------------------------------------
  describe "#post_file_url" do
    let(:post) do
      instance_double(Post,
                      md5: md5, file_ext: "jpg",
                      protect_file?: false, has_preview?: true)
    end

    it "returns the full URL using the post's md5 and extension" do
      expect(manager.post_file_url(post, :original)).to eq("http://example.com/data/#{md5}.jpg")
    end

    context "when post.protect_file? is true" do
      include_context "as member"

      it "delegates the protect flag to post.protect_file?" do
        allow(post).to receive(:protect_file?).and_return(true)
        url = manager.post_file_url(post, :original)
        expect(url).to include("?auth=")
      end
    end

    context "when has_preview? is false and type is :preview_jpg" do
      it "returns the download-preview fallback" do
        allow(post).to receive(:has_preview?).and_return(false)
        expect(manager.post_file_url(post, :preview_jpg)).to eq("/images/download-preview.png")
      end
    end

    context "when has_preview? is false and type is :preview" do
      it "returns the download-preview fallback" do
        allow(post).to receive(:has_preview?).and_return(false)
        expect(manager.post_file_url(post, :preview)).to eq("/images/download-preview.png")
      end
    end
  end
end
