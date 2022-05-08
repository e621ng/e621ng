require 'test_helper'

class UploadServiceTest < ActiveSupport::TestCase
  setup do
    Timecop.travel(2.weeks.ago) do
      @user = FactoryBot.create(:user)
    end
    CurrentUser.user = @user
    CurrentUser.ip_addr = "127.0.0.1"
    UploadWhitelist.create!(pattern: '*', reason: 'test')
  end

  context "::Utils" do
    subject { UploadService::Utils }

    context "#get_file_for_upload" do
      context "for a non-source site" do
        setup do
          @source = "https://upload.wikimedia.org/wikipedia/commons/c/c5/Moraine_Lake_17092005.jpg"
          @upload = Upload.new
          @upload.source = @source
        end

        should "work on a jpeg" do
          file = subject.get_file_for_upload(@upload)

          assert_operator(File.size(file.path), :>, 0)

          file.close
        end
      end

      context "for a corrupt jpeg" do
        setup do
          @source = "https://raikou1.donmai.us/93/f4/93f4dd66ef1eb11a89e56d31f9adc8d0.jpg"
          @mock_upload = mock("upload")
          @mock_upload.stubs(:direct_url_parsed).returns(@source)
          @bad_file = File.open("#{Rails.root}/test/files/test-corrupt.jpg", "rb")
          Downloads::File.any_instance.stubs(:download!).returns(@bad_file)
        end

        teardown do
          @bad_file.close
        end

        should "retry three times" do
          DanbooruImageResizer.expects(:validate_shell).times(4).returns(false)
          assert_raise(UploadService::Utils::CorruptFileError) do
            subject.get_file_for_upload(@mock_upload)
          end
        end
      end
    end

    context ".calculate_dimensions" do
      context "for a video" do
        setup do
          @file = File.open("test/files/test-512x512.webm", "rb")
          @upload = Upload.new(file_ext: "webm")
        end

        teardown do
          @file.close
        end

        should "return the dimensions" do
          w, h = @upload.calculate_dimensions(@file.path)
          assert_operator(w, :>, 0)
          assert_operator(h, :>, 0)
        end
      end

      context "for an image" do
        setup do
          @file = File.open("test/files/test.jpg", "rb")
          @upload = Upload.new(file_ext: "jpg")
        end

        teardown do
          @file.close
        end

        should "find the dimensions" do
          w, h = @upload.calculate_dimensions(@file.path)
          assert_operator(w, :>, 0)
          assert_operator(h, :>, 0)
        end
      end
    end

    context ".generate_resizes" do
      context "for a video" do
        teardown do
          @file.close
        end

        context "for a webm" do
          setup do
            @file = File.open("test/files/test-512x512.webm", "rb")
            @upload = mock()
            @upload.stubs(:is_video?).returns(true)
          end

          should "generate a video" do
            preview, crop, sample = subject.generate_resizes(@file, @upload)
            assert_operator(File.size(preview.path), :>, 0)
            assert_operator(File.size(crop.path), :>, 0)
            assert_equal(150, ImageSpec.new(preview.path).width)
            assert_equal(150, ImageSpec.new(preview.path).height)
            assert_equal(150, ImageSpec.new(crop.path).width)
            assert_equal(150, ImageSpec.new(crop.path).height)
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
          @upload = mock()
          @upload.stubs(:is_video?).returns(false)
          @upload.stubs(:is_image?).returns(true)
          @upload.stubs(:image_width).returns(1200)
          @upload.stubs(:image_height).returns(200)
        end

        context "for a jpeg" do
          setup do
            @file = File.open("test/files/test.jpg", "rb")
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
            @file = File.open("test/files/test.png", "rb")
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
            @file = File.open("test/files/test.png", "rb")
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
          @path = "test/files/test-300x300.mp4"
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
          @path = "test/files/test-512x512.webm"
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
      CurrentUser.user = FactoryBot.create(:user, created_at: 1.month.ago)
      CurrentUser.ip_addr = "127.0.0.1"
      @build_service = ->(**params) { subject.new({ rating: "s", uploader: CurrentUser.user, uploader_ip_addr: CurrentUser.ip_addr }.merge(params)) }
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "automatic tagging" do
      should "tag animated png files" do
        service = @build_service.call(file: upload_file("test/files/apng/normal_apng.png"))
        upload = service.start!
        puts upload.errors.full_messages.join('; ')
        assert_match(/animated_png/, upload.tag_string)
      end

      should "tag animated gif files" do
        service = @build_service.call(file: upload_file("test/files/test-animated-86x52.gif"))
        upload = service.start!
        assert_match(/animated_gif/, upload.tag_string)
      end

      should "not tag static gif files" do
        service = @build_service.call(file: upload_file("test/files/test-static-32x32.gif"))
        upload = service.start!
        assert_no_match(/animated_gif/, upload.tag_string)
      end
    end

    context "that is too large" do
      setup do
        Danbooru.config.stubs(:max_image_resolution).returns(31*31)
      end

      should "should fail validation" do
        service = @build_service.call(file: upload_file("test/files/test-large.jpg"))
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
      should "upload successfully" do
        source1 = "https://raikou1.donmai.us/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg?one=東方&two=a%20b"
        source2 = "https://raikou1.donmai.us/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg?one=%E6%9D%B1%E6%96%B9&two=a%20b"
        service = @build_service.call(source: source1, rating: "s")

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_completed?)
        assert_equal(source2, @upload.source)
      end

      should "normalize unicode characters in the source field" do
        source1 = "poke\u0301mon" # pokémon (nfd form)
        source2 = "pok\u00e9mon"  # pokémon (nfc form)
        service = @build_service.call(source: source1, rating: "s", file: upload_file("test/files/test.jpg"))

        assert_nothing_raised { @upload = service.start! }
        assert_equal(source2, @upload.source)
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
        service = @build_service.call(file: upload_file("test/files/test.jpg"), source: "http://www.example.com", rating: "s")

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
      CurrentUser.ip_addr = "127.0.0.1"
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "for an image" do
      setup do
        @upload = FactoryBot.create(:source_upload, file_size: 1000, md5: "12345", file_ext: "jpg", image_width: 100, image_height: 100)
      end

      should "create a post" do
        post = subject.new({}).create_post_from_upload(@upload)
        assert_equal([], post.errors.full_messages)
        assert_not_nil(post.id)
      end
    end
  end
end
