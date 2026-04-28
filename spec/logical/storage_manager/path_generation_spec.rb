# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager do
  let(:md5) { "abcdef1234567890abcdef1234567890" }

  # Use Local as a concrete subclass so path methods are exercisable without mocking store/delete/open.
  let(:manager) do
    StorageManager::Local.new(base_dir: "/data", hierarchical: false, base_url: "http://example.com")
  end
  let(:hier_manager) do
    StorageManager::Local.new(base_dir: "/data", hierarchical: true, base_url: "http://example.com")
  end

  # -------------------------------------------------------------------------
  # #subdir_for
  # -------------------------------------------------------------------------
  describe "#subdir_for" do
    context "when non-hierarchical" do
      it "returns an empty string" do
        expect(manager.subdir_for(md5)).to eq("")
      end
    end

    context "when hierarchical" do
      it "returns the first two pairs of hex chars as nested directories" do
        expect(hier_manager.subdir_for(md5)).to eq("ab/cd/")
      end
    end
  end

  # -------------------------------------------------------------------------
  # #file_name
  # -------------------------------------------------------------------------
  describe "#file_name" do
    it "returns md5.jpg for :preview type" do
      expect(manager.file_name(md5, "jpg", :preview)).to eq("#{md5}.jpg")
    end

    it "returns md5.jpg for :crop type" do
      expect(manager.file_name(md5, "jpg", :crop)).to eq("#{md5}.jpg")
    end

    it "returns md5.jpg for :large type (default empty prefix)" do
      expect(manager.file_name(md5, "jpg", :large)).to eq("#{md5}.jpg")
    end

    it "preserves the extension for :original type" do
      expect(manager.file_name(md5, "png", :original)).to eq("#{md5}.png")
    end

    it "appends the scale factor for :scaled type" do
      expect(manager.file_name(md5, "mp4", :scaled, scale_factor: "360")).to eq("#{md5}_360.mp4")
    end
  end

  # -------------------------------------------------------------------------
  # #file_path_base
  # -------------------------------------------------------------------------
  describe "#file_path_base" do
    context "with type :original" do
      it "returns /md5.ext" do
        expect(manager.file_path_base(md5, "jpg", :original)).to eq("/#{md5}.jpg")
      end
    end

    context "with type :preview_jpg" do
      it "returns /preview/md5.jpg" do
        expect(manager.file_path_base(md5, "jpg", :preview_jpg)).to eq("/preview/#{md5}.jpg")
      end
    end

    context "with type :preview (compatibility alias)" do
      it "returns /preview/md5.jpg" do
        expect(manager.file_path_base(md5, "jpg", :preview)).to eq("/preview/#{md5}.jpg")
      end
    end

    context "with type :preview_webp" do
      it "returns /preview/md5.webp" do
        expect(manager.file_path_base(md5, "webp", :preview_webp)).to eq("/preview/#{md5}.webp")
      end
    end

    context "with type :sample_jpg" do
      it "returns /sample/md5.jpg" do
        expect(manager.file_path_base(md5, "jpg", :sample_jpg)).to eq("/sample/#{md5}.jpg")
      end
    end

    context "with type :sample (compatibility alias)" do
      it "returns /sample/md5.jpg" do
        expect(manager.file_path_base(md5, "jpg", :sample)).to eq("/sample/#{md5}.jpg")
      end
    end

    context "with type :sample_webp" do
      it "returns /sample/md5.webp" do
        expect(manager.file_path_base(md5, "webp", :sample_webp)).to eq("/sample/#{md5}.webp")
      end
    end

    context "with type :scaled and a scale" do
      it "returns /sample/md5_scale.mp4" do
        expect(manager.file_path_base(md5, "mp4", :scaled, scale: "360")).to eq("/sample/#{md5}_360.mp4")
      end
    end

    context "with type :crop" do
      it "returns /crop/md5.jpg" do
        expect(manager.file_path_base(md5, "jpg", :crop)).to eq("/crop/#{md5}.jpg")
      end
    end

    context "with protect: true" do
      it "prepends the protected prefix" do
        path = manager.file_path_base(md5, "jpg", :original, protect: true)
        expect(path).to eq("/deleted/#{md5}.jpg")
      end
    end

    context "with an unknown type" do
      it "raises StorageManager::Error" do
        expect { manager.file_path_base(md5, "jpg", :bogus) }.to raise_error(StorageManager::Error, /Unknown file type/)
      end
    end

    context "when hierarchical" do
      it "inserts the two-level subdir into the path" do
        path = hier_manager.file_path_base(md5, "jpg", :original)
        expect(path).to eq("/ab/cd/#{md5}.jpg")
      end
    end
  end

  # -------------------------------------------------------------------------
  # #file_path
  # -------------------------------------------------------------------------
  describe "#file_path" do
    it "prepends base_dir to the file_path_base" do
      expect(manager.file_path(md5, "jpg", :original)).to eq("/data/#{md5}.jpg")
    end

    it "handles the protect flag" do
      expect(manager.file_path(md5, "jpg", :original, protect: true)).to eq("/data/deleted/#{md5}.jpg")
    end
  end

  # -------------------------------------------------------------------------
  # #post_file_path
  # -------------------------------------------------------------------------
  describe "#post_file_path" do
    let(:post) do
      instance_double(Post,
                      md5: md5, file_ext: "jpg",
                      protect_file?: false, has_preview?: true)
    end

    it "returns the full file path using the post's md5 and extension" do
      expect(manager.post_file_path(post, :original)).to eq("/data/#{md5}.jpg")
    end

    it "uses post.protect_file? for the protect flag" do
      allow(post).to receive(:protect_file?).and_return(true)
      expect(manager.post_file_path(post, :original)).to eq("/data/deleted/#{md5}.jpg")
    end

    context "when has_preview? is false and type is :preview_jpg" do
      it "returns the download-preview fallback path" do
        allow(post).to receive(:has_preview?).and_return(false)
        expect(manager.post_file_path(post, :preview_jpg)).to eq("/images/download-preview.png")
      end
    end

    context "when has_preview? is false and type is :preview" do
      it "returns the download-preview fallback path" do
        allow(post).to receive(:has_preview?).and_return(false)
        expect(manager.post_file_path(post, :preview)).to eq("/images/download-preview.png")
      end
    end

    context "when has_preview? is true and type is :preview_jpg" do
      it "returns the actual preview path" do
        expect(manager.post_file_path(post, :preview_jpg)).to eq("/data/preview/#{md5}.jpg")
      end
    end
  end
end
