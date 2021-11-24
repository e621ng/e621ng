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
          @upload = create(:upload, direct_url: @source)
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
          @bad_file = File.open(Rails.root.join("test/files/test-corrupt.jpg"), "rb")
        end

        should "not upload" do
          assert_difference(-> { Post.count }, 0) do
            @upload = UploadService.new(FactoryBot.attributes_for(:upload).merge(file: @bad_file, uploader: @user, uploader_ip_addr: '127.0.0.1')).start!
            assert @upload.status.include? "File is corrupt"
          end
        end
      end
    end

    context ".generate_resizes" do
      context "for a video" do
        context "for a webm" do
          setup do
            @upload = UploadService.new(FactoryBot.attributes_for(:upload).merge(file: upload_file("test/files/test-512x512.webm"), uploader: @user, uploader_ip_addr: '127.0.0.1')).start!
            PostVideoConversionJob.drain
            @post = @upload.post
          end

          should "generate video samples" do
            assert @post.has_sample_size?("480p")
            assert @post.has_sample_size?("original")
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
  end

  context "#start!" do
    subject { UploadService }

    setup do
      @source = "https://raikou1.donmai.us/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg"
      CurrentUser.user = travel_to(1.month.ago) do
        FactoryBot.create(:user)
      end
      CurrentUser.ip_addr = "127.0.0.1"
    end

    teardown do
      CurrentUser.user = nil
      CurrentUser.ip_addr = nil
    end

    context "automatic tagging" do
      setup do
        @build_service = ->(file) { subject.new(FactoryBot.attributes_for(:upload).merge(file: file, uploader: @user, uploader_ip_addr: '127.0.0.1'))}
      end

      should "tag animated png files" do
        service = @build_service.call(upload_file("test/files/apng/normal_apng.png"))
        upload = service.start!
        assert_match(/animated_png/, upload.tag_string)
      end

      should "tag animated gif files" do
        service = @build_service.call(upload_file("test/files/test-animated-86x52.gif"))
        upload = service.start!
        assert_match(/animated_gif/, upload.tag_string)
      end

      should "not tag static gif files" do
        service = @build_service.call(upload_file("test/files/test-static-32x32.gif"))
        upload = service.start!
        assert_no_match(/animated_gif/, upload.tag_string)
      end
    end

    context "that is too large" do
      setup do
        Danbooru.config.stubs(:max_image_resolution).returns(31*31)
      end

      should "should fail validation" do
        service = subject.new(FactoryBot.attributes_for(:upload).merge(file: upload_file("test/files/test-large.jpg"), uploader: @user, uploader_ip_addr: '127.0.0.1'))
        upload = service.start!
        assert_match(/image resolution is too large/, upload.status)
      end
    end

    context "with no predecessor" do
      should "create an upload" do
        service = subject.new(FactoryBot.attributes_for(:jpg_upload).merge(uploader: @user, uploader_ip_addr: '127.0.0.1'))

        assert_difference(-> { Upload.count }) do
          service.start!
        end
      end

      should "prevent uploads on duplicates" do
        service = subject.new(uploader: @user, uploader_ip_addr: CurrentUser.ip_addr, source: "", rating: "s", file: upload_file("test/files/test.jpg"))
        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_completed?)
        assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @upload.post.md5)

        service = subject.new(uploader: @user, uploader_ip_addr: CurrentUser.ip_addr, source: "", rating: "s", file: upload_file("test/files/test.jpg"))
        assert_nothing_raised { @upload = service.start! }
        assert(@upload.status.include?("Md5 duplicate"))
        assert_nil(@upload.post)
      end

      should "prevent uploads of invalid filetypes" do
        service = subject.new(uploader: @user, uploader_ip_addr: CurrentUser.ip_addr, source: "", rating: "s", file: upload_file("test/files/test-300x300.mp4"))
        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_errored?)
        assert_nil(@upload.post)
      end

      should "assign the rating from tags" do
        service = subject.new(FactoryBot.attributes_for(:jpg_upload).merge(source: @source, tag_string: "rating:safe blah", uploader: @user, uploader_ip_addr: '127.0.0.1'))
        upload = service.start!

        assert_equal(true, upload.valid?)
        assert_equal("s", upload.rating)
        assert_equal("rating:safe blah ", upload.tag_string)

        assert_equal("s", upload.post.rating)
        assert_equal("blah low_res", upload.post.tag_string)
      end
    end

    context "with a source containing unicode characters" do
      should "upload successfully" do
        source = "https://raikou1.donmai.us/d3/4e/d34e4cf0a437a5d65f8e82b7bcd02606.jpg?one=東方&two=a%20b"
        service = subject.new(FactoryBot.attributes_for(:jpg_upload).merge(source: source, uploader: @user, uploader_ip_addr: '127.0.0.1'))

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_completed?)
        assert_equal(source, @upload.source)
      end
    end

    context "without a file or a source url" do
      should "fail gracefully" do
        service = subject.new(FactoryBot.attributes_for(:upload).merge(uploader: @user, uploader_ip_addr: '127.0.0.1'))

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_errored?)
        assert_match(/No file or source URL provided/, @upload.status)
      end
    end

    context "with both a file and a source url" do
      should "upload the file and set the source field to the given source" do
        service = subject.new(FactoryBot.attributes_for(:jpg_upload).merge(source: "http://www.example.com", uploader: @user, uploader_ip_addr: '127.0.0.1'))

        assert_nothing_raised { @upload = service.start! }
        assert_equal(true, @upload.is_completed?)
        assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @upload.md5)
        assert_equal("http://www.example.com", @upload.source)
      end
    end
  end

  context "#create_post_from_upload" do
    subject { UploadService }

    context "for a pixiv" do
      setup do
        @source = "https://i.pximg.net/img-original/img/2017/11/21/05/12/37/65981735_p0.jpg"
        @upload = FactoryBot.create(:jpg_upload, source: @source)
      end

      should "record the canonical source" do
        post = subject.new({}).create_post_from_upload(@upload)
        assert_equal("#{@source}\nhttps://www.pixiv.net/artworks/65981735", post.source)
      end
    end

    context "for an image" do
      setup do
        @upload = FactoryBot.create(:source_upload)
      end

      should "create a post" do
        post = subject.new({}).create_post_from_upload(@upload)
        assert_equal([], post.errors.full_messages)
        assert_not_nil(post.id)
      end
    end

  end
end
