# frozen_string_literal: true

require "rails_helper"

RSpec.describe StorageManager::Local do
  let(:tmpdir) { Dir.mktmpdir }
  let(:manager) { described_class.new(base_dir: tmpdir, hierarchical: false) }
  let(:md5) { "abcdef1234567890abcdef1234567890" }

  let(:post) do
    instance_double(Post,
                    md5: md5, file_ext: "jpg",
                    protect_file?: false, has_preview?: true, is_video?: false)
  end

  after { FileUtils.remove_entry(tmpdir) }

  # Helper: return public and protected paths for a given type.
  def public_path(type, scale: nil)
    manager.file_path(md5, "jpg", type, protect: false, scale: scale)
  end

  def protected_path(type, scale: nil)
    manager.file_path(md5, "jpg", type, protect: true, scale: scale)
  end

  def mp4_public_path(scale)
    manager.file_path(md5, "mp4", :scaled, protect: false, scale: scale)
  end

  def mp4_protected_path(scale)
    manager.file_path(md5, "mp4", :scaled, protect: true, scale: scale)
  end

  # -------------------------------------------------------------------------
  # #move_file_delete
  # -------------------------------------------------------------------------
  describe "#move_file_delete" do
    context "with a non-video post" do
      it "moves all IMAGE_TYPE files from public to protected paths" do
        StorageManager::IMAGE_TYPES.each do |type|
          path = public_path(type)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.touch(path)
        end

        manager.move_file_delete(post)

        StorageManager::IMAGE_TYPES.each do |type|
          expect(File.exist?(public_path(type))).to be(false), "expected #{type} to be removed from public path"
          expect(File.exist?(protected_path(type))).to be(true), "expected #{type} to exist at protected path"
        end
      end

      it "creates the protected target directories as needed" do
        original = public_path(:original)
        FileUtils.mkdir_p(File.dirname(original))
        FileUtils.touch(original)

        manager.move_file_delete(post)

        expect(File.exist?(protected_path(:original))).to be(true)
      end

      it "does not raise when a source file is missing" do
        expect { manager.move_file_delete(post) }.not_to raise_error
      end

      it "does not process video samples" do
        allow(manager).to receive(:move_file)
        manager.move_file_delete(post)
        expect(manager).not_to have_received(:move_file).with(anything, mp4_protected_path("alt"))
      end
    end

    context "with a video post" do
      let(:post) do
        instance_double(Post,
                        md5: md5, file_ext: "jpg",
                        protect_file?: false, has_preview?: true, is_video?: true,
                        video_sample_list: { variants: { "alt" => {} } })
      end

      it "moves the alt variant file from public to protected" do
        alt_path = mp4_public_path("alt")
        FileUtils.mkdir_p(File.dirname(alt_path))
        FileUtils.touch(alt_path)

        manager.move_file_delete(post)

        expect(File.exist?(mp4_public_path("alt"))).to be(false)
        expect(File.exist?(mp4_protected_path("alt"))).to be(true)
      end

      it "moves each video sample file from public to protected" do
        Danbooru.config.video_samples.each_key do |scale|
          path = mp4_public_path(scale)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.touch(path)
        end

        manager.move_file_delete(post)

        Danbooru.config.video_samples.each_key do |scale|
          expect(File.exist?(mp4_public_path(scale))).to be(false)
          expect(File.exist?(mp4_protected_path(scale))).to be(true)
        end
      end
    end
  end

  # -------------------------------------------------------------------------
  # #move_file_undelete
  # -------------------------------------------------------------------------
  describe "#move_file_undelete" do
    context "with a non-video post" do
      it "moves all IMAGE_TYPE files from protected to public paths" do
        StorageManager::IMAGE_TYPES.each do |type|
          path = protected_path(type)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.touch(path)
        end

        manager.move_file_undelete(post)

        StorageManager::IMAGE_TYPES.each do |type|
          expect(File.exist?(protected_path(type))).to be(false), "expected #{type} to be removed from protected path"
          expect(File.exist?(public_path(type))).to be(true), "expected #{type} to exist at public path"
        end
      end

      it "does not raise when a source file is missing" do
        expect { manager.move_file_undelete(post) }.not_to raise_error
      end
    end

    context "with a video post" do
      let(:post) do
        instance_double(Post,
                        md5: md5, file_ext: "jpg",
                        protect_file?: false, has_preview?: true, is_video?: true,
                        video_sample_list: { variants: { "alt" => {} } })
      end

      it "moves the alt variant file from protected to public" do
        alt_path = mp4_protected_path("alt")
        FileUtils.mkdir_p(File.dirname(alt_path))
        FileUtils.touch(alt_path)

        manager.move_file_undelete(post)

        expect(File.exist?(mp4_protected_path("alt"))).to be(false)
        expect(File.exist?(mp4_public_path("alt"))).to be(true)
      end

      it "moves each video sample file from protected to public" do
        Danbooru.config.video_samples.each_key do |scale|
          path = mp4_protected_path(scale)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.touch(path)
        end

        manager.move_file_undelete(post)

        Danbooru.config.video_samples.each_key do |scale|
          expect(File.exist?(mp4_protected_path(scale))).to be(false)
          expect(File.exist?(mp4_public_path(scale))).to be(true)
        end
      end
    end
  end
end
