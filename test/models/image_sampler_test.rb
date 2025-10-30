# frozen_string_literal: true

require "test_helper"

class ImageSamplerTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    CurrentUser.user = @user
    UploadWhitelist.create!(domain: ".*", reason: "test")
  end

  context "ImageSampler" do
    subject { ImageSampler }

    context "for an image" do
      context "jpg" do
        setup do
          @file = file_fixture("test.jpg").open
        end

        teardown do
          @file&.close
        end

        should "generate a preview" do
          image = subject.image_from_path(@file.path)

          # Thumbnail
          subject.thumbnail(image, [500, 335]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.small_image_width, s_image.height)
            file.close
            file.unlink
          end

          # Sample
          subject.sample(image, [500, 335]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.large_image_width, s_image.height)
            file.close
            file.unlink
          end
        end
      end

      context "png" do
        setup do
          @file = file_fixture("bread-static.alt.png").open
        end

        teardown do
          @file&.close
        end

        should "generate a preview" do
          image = subject.image_from_path(@file.path)

          # Thumbnail
          subject.thumbnail(image, [512, 512]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.small_image_width, s_image.width)
            file.close
            file.unlink
          end

          # Sample
          subject.sample(image, [512, 512]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.large_image_width, s_image.width)
            file.close
            file.unlink
          end
        end
      end

      context "gif" do
        setup do
          @file = file_fixture("bread-animated.gif").open
        end

        teardown do
          @file&.close
        end

        should "generate a preview" do
          image = subject.image_from_path(@file.path)

          # Thumbnail
          subject.thumbnail(image, [256, 256]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.small_image_width, s_image.width)
            file.close
            file.unlink
          end

          # Sample
          subject.sample(image, [256, 256]).each_value do |file|
            s_image = Vips::Image.new_from_file(file.path)
            assert_operator(File.size(file.path), :>, 0)
            assert_equal(Danbooru.config.large_image_width, s_image.width)
            file.close
            file.unlink
          end
        end
      end

      context "for a video" do
        context "webm" do
          setup do
            @file = file_fixture("test-512x512.webm").open
          end

          teardown do
            @file&.close
          end

          should "generate a preview" do
            image = subject.image_from_path(@file.path, is_video: true)

            # Thumbnail
            subject.thumbnail(image, [512, 512]).each_value do |file|
              s_image = Vips::Image.new_from_file(file.path)
              assert_operator(File.size(file.path), :>, 0)
              assert_equal(Danbooru.config.small_image_width, s_image.width)
              file.close
              file.unlink
            end

            # Sample
            subject.sample(image, [512, 512]).each_value do |file|
              s_image = Vips::Image.new_from_file(file.path)
              assert_operator(File.size(file.path), :>, 0)
              assert_equal(Danbooru.config.large_image_width, s_image.width)
              file.close
              file.unlink
            end
          end
        end

        context "mp4" do
          setup do
            @file = file_fixture("test-300x300.mp4").open
          end

          teardown do
            @file&.close
          end

          should "generate a preview" do
            image = subject.image_from_path(@file.path, is_video: true)

            # Thumbnail
            subject.thumbnail(image, [300, 300]).each_value do |file|
              s_image = Vips::Image.new_from_file(file.path)
              assert_operator(File.size(file.path), :>, 0)
              assert_equal(Danbooru.config.small_image_width, s_image.width)
              file.close
              file.unlink
            end

            # Sample
            subject.sample(image, [300, 300]).each_value do |file|
              s_image = Vips::Image.new_from_file(file.path)
              assert_operator(File.size(file.path), :>, 0)
              assert_equal(Danbooru.config.large_image_width, s_image.width)
              file.close
              file.unlink
            end
          end
        end
      end
    end
  end
end
