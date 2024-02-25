# frozen_string_literal: true

require "test_helper"

class UploadServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    CurrentUser.user = @user
    UploadWhitelist.create!(pattern: '*', reason: 'test')
  end

  context "::Utils" do
    subject { UploadService::Utils }

    context "#get_file_for_upload" do
      context "for a non-source site" do
        setup do
          @source = "https://upload.wikimedia.org/wikipedia/commons/c/c5/Moraine_Lake_17092005.jpg"
          @upload = Upload.new
          @upload.direct_url = @source
          Downloads::File.any_instance.stubs(:download!).returns(fixture_file_upload("test.jpg"))
        end

        should "work on a jpeg" do
          file = subject.get_file_for_upload(@upload)

          assert_operator(File.size(file.path), :>, 0)

          file.close
        end
      end
    end

    context ".calculate_dimensions" do
      context "for a video" do
        setup do
          @path = file_fixture("test-512x512.webm").to_s
          @upload = Upload.new(file_ext: "webm")
        end

        should "return the dimensions" do
          w, h = @upload.calculate_dimensions(@path)
          assert_operator(w, :>, 0)
          assert_operator(h, :>, 0)
        end
      end

      context "for an image" do
        setup do
          @path = file_fixture("test.jpg").to_s
          @upload = Upload.new(file_ext: "jpg")
        end

        should "find the dimensions" do
          w, h = @upload.calculate_dimensions(@path)
          assert_operator(w, :>, 0)
          assert_operator(h, :>, 0)
        end
      end
    end

    context ".generate_resizes" do
      context "for a video" do
        context "for a webm" do
          setup do
            @file = file_fixture("test-512x512.webm").open
            @upload = UploadService.new(attributes_for(:upload).merge(file: @file, uploader: @user)).start!
          end

          teardown do
            @file.close
          end

          should "generate a video" do
            preview, crop, sample = subject.generate_resizes(@file, @upload)
            assert_operator(File.size(preview.path), :>, 0)
            assert_operator(File.size(crop.path), :>, 0)
            preview_image = Vips::Image.new_from_file(preview.path)
            crop_image = Vips::Image.new_from_file(crop.path)
            assert_equal(150, preview_image.width)
            assert_equal(150, preview_image.height)
            assert_equal(150, crop_image.width)
            assert_equal(150, crop_image.height)
            preview.close
            preview.unlink
            crop.close
            crop.unlink
          end
        end
      end

      context "for an image" do
        teardown do
          @file.close
        end

        setup do
          @upload = mock
          @upload.stubs(:is_video?).returns(false)
          @upload.stubs(:is_image?).returns(true)
          @upload.stubs(:image_width).returns(1200)
          @upload.stubs(:image_height).returns(200)
        end

        context "for a jpeg" do
          setup do
            @file = file_fixture("test.jpg").open
          end

          should "generate a preview" do
            preview, crop, sample = subject.generate_resizes(@file, @upload)
            assert_operator(File.size(preview.path), :>, 0)
            assert_operator(File.size(crop.path), :>, 0)
            assert_operator(File.size(sample.path), :>, 0)
            preview.close
            preview.unlink
            sample.close
            sample.unlink
          end
        end

        context "for a png" do
          setup do
            @file = file_fixture("test.png").open
          end

          should "generate a preview" do
            preview, crop, sample = subject.generate_resizes(@file, @upload)
            assert_operator(File.size(preview.path), :>, 0)
            assert_operator(File.size(crop.path), :>, 0)
            assert_operator(File.size(sample.path), :>, 0)
            preview.close
            preview.unlink
            sample.close
            sample.unlink
          end
        end

        context "for a gif" do
          setup do
            @file = file_fixture("test.gif").open
          end

          should "generate a preview" do
            preview, crop, sample = subject.generate_resizes(@file, @upload)
            assert_operator(File.size(preview.path), :>, 0)
            assert_operator(File.size(crop.path), :>, 0)
            assert_operator(File.size(sample.path), :>, 0)
            preview.close
            preview.unlink
            sample.close
            sample.unlink
          end
        end
      end
    end

    context ".generate_video_preview_for" do
      context "for an mp4" do
        setup do
          @path = file_fixture("test-300x300.mp4").to_s
        end

        should "generate a video" do
          sample = PostThumbnailer.generate_video_preview_for(@path, 100)
          assert_operator(File.size(sample.path), :>, 0)
          sample.close
          sample.unlink
        end
      end

      context "for a webm" do
        setup do
          @path = file_fixture("test-512x512.webm").to_s
        end

        should "generate a video" do
          sample = PostThumbnailer.generate_video_preview_for(@path, 100)
          assert_operator(File.size(sample.path), :>, 0)
          sample.close
          sample.unlink
        end
      end
    end
  end

  context "#start!" do
    subject { UploadService }

    setup do
      @source = "https://raikou1.donmai.us/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg"
      CurrentUser.user = create(:user, created_at: 1.month.ago)
      @build_service = ->(**params) { subject.new({ rating: "s", uploader: CurrentUser.user, uploader_ip_addr: CurrentUser.ip_addr }.merge(params)) }
    end

    context "automatic tagging" do
      should "tag animated png files" do
        service = @build_service.call(file: fixture_file_upload("apng/normal_apng.png"))
        upload = service.start!
        assert_match(/animated_png/, upload.tag_string)
      end

      should "tag animated gif files" do
        service = @build_service.call(file: fixture_file_upload("test-animated-86x52.gif"))
        upload = service.start!
        assert_match(/animated_gif/, upload.tag_string)
      end

      should "not tag static gif files" do
        service = @build_service.call(file: fixture_file_upload("test-static-32x32.gif"))
        upload = service.start!
        assert_no_match(/animated_gif/, upload.tag_string)
      end
    end

    context "that is too large" do
      setup do
        Danbooru.config.stubs(:max_image_resolution).returns(31 * 31)
      end

      should "should fail validation" do
        service = @build_service.call(file: fixture_file_upload("test-large.jpg"))
        upload = service.start!
        assert_match(/image resolution is too large/, upload.status)
      end
    end

    should "create an upload" do
      service = @build_service.call(source: @source)

      assert_difference(-> { Upload.count }) do
        service.start!
      end
    end

    should "assign the rating from tags" do
      service = @build_service.call(source: @source, rating: "s", tag_string: "blah")
      post = service.start!

      assert_equal(true, post.valid?)
      assert_equal("s", post.rating)
      assert_equal("blah", post.tag_string)
    end

    context "with a source containing unicode characters" do
      should "normalize unicode characters in the source field" do
        source1 = "poke\u0301mon" # pokémon (nfd form)
        source2 = "pok\u00e9mon"  # pokémon (nfc form)
        service = @build_service.call(source: source1, rating: "s", file: fixture_file_upload("test.jpg"))

        assert_nothing_raised { @upload = service.start! }
        assert_equal(source2, @upload.post.source)
      end
    end

    context "without a file or a source url" do
      should "fail gracefully" do
        service = @build_service.call(source: "blah", rating: "s")

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_errored?)
        assert_match(/No file or source URL provided/, @upload.status)
      end
    end

    context "with both a file and a source url" do
      should "upload the file and set the source field to the given source" do
        service = @build_service.call(file: fixture_file_upload("test.jpg"), source: "http://www.example.com", rating: "s")

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_completed?)
        assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @upload.md5)
        assert_equal("http://www.example.com", @upload.source)
      end
    end
  end

  context "#create_post_from_upload" do
    subject { UploadService }

    setup do
      CurrentUser.user = create(:user, created_at: 1.month.ago)
    end

    context "for an image" do
      setup do
        @upload = create(:source_upload, file_size: 1000, md5: "12345", file_ext: "jpg", image_width: 100, image_height: 100, file: Tempfile.new)
      end

      should "create a post" do
        post = subject.new({}).create_post_from_upload(@upload)
        assert_equal([], post.errors.full_messages)
        assert_not_nil(post.id)
      end
    end
  end
end
