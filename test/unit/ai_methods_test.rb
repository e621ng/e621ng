# frozen_string_literal: true

require "test_helper"

class AiMethodsTest < ActiveSupport::TestCase
  include AiMethods

  # Simple fake image object to simulate ruby-vips metadata access
  class FakeVipsImage
    def initialize(values: {}, fields: nil, raise_on_get_fields: false)
      @values = values
      @fields = fields || []
      @raise_on_get_fields = raise_on_get_fields
    end

    def get_fields # rubocop:disable Naming/AccessorMethodName
      raise((defined?(Vips::Error) ? Vips::Error : StandardError), "boom") if @raise_on_get_fields
      @fields
    end

    def get(key)
      @values.fetch(key) { raise((defined?(Vips::Error) ? Vips::Error : StandardError), key) }
    end
  end

  # Ensure Vips::Error exists even if libvips isn't loaded during tests
  module ::Vips; class Error < StandardError; end unless const_defined?(:Error); end

  def stub_vips_image(values: {}, fields: [], raise_on_get_fields: false)
    fake = FakeVipsImage.new(values: values, fields: fields, raise_on_get_fields: raise_on_get_fields)
    Vips::Image.stubs(:new_from_file).returns(fake)
    # Stub File.exist? to return true for any path since we're using fake paths in tests
    File.stubs(:exist?).returns(true)
  end

  test "returns not an image for non-image files" do
    result = is_ai_generated?("/tmp/readme.txt")
    assert_equal 0, result[:score]
    assert_equal "not an image", result[:reason]
  end

  test "returns file not found for non-existent files" do
    # Don't stub File.exist? for this test, so it returns false for non-existent files
    result = is_ai_generated?("/tmp/nonexistent.jpg")
    assert_equal 0, result[:score]
    assert_equal "file not found", result[:reason]
  end

  test "detects C2PA manifest via XMP" do
    stub_vips_image(values: {
      "exif-data" => "",
      "exif-ifd0-Software" => "",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "",
      "xmp-data" => "This image includes c2pa.org manifest",
      "jpeg-comment" => "",
      "jpeg-com" => "",
    })

    result = is_ai_generated?("/tmp/photo.jpg")
    assert_equal 80, result[:score]
    assert_includes result[:reason], "c2pa manifest present"
  end

  test "detects known generator (Midjourney)" do
    stub_vips_image(values: {
      "exif-data" => "",
      "exif-ifd0-Software" => "Generated with Midjourney",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "",
      "xmp-data" => "",
      "jpeg-comment" => "",
      "jpeg-com" => "",
    })

    result = is_ai_generated?("/tmp/render.jpeg")
    assert_equal 70, result[:score]
    assert_includes result[:reason], "ai generator: midjourney"
  end

  test "detects Stable Diffusion parameter tokens" do
    stub_vips_image(values: {
      "exif-data" => "",
      "exif-ifd0-Software" => "",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "Negative prompt: lowres",
      "xmp-data" => "",
      "jpeg-comment" => "",
      "jpeg-com" => "",
    })

    result = is_ai_generated?("/tmp/picture.jpg")
    assert_equal 60, result[:score]
    assert_includes result[:reason], "ai parameter tokens found"
  end

  test "PNG text markers add 20 without SD tokens" do
    # Use only the word "Dream" to avoid triggering SD_TOKENS (which would add +60)
    fields = ["png-comment-0"]
    stub_vips_image(values: {
      "exif-data" => "",
      "exif-ifd0-Software" => "",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "",
      "xmp-data" => "",
      "jpeg-comment" => "",
      "jpeg-com" => "",
      "png-comment-0" => "Dream by user",
    }, fields: fields)

    result = is_ai_generated?("/tmp/image.png")
    assert_equal 20, result[:score]
    assert_includes result[:reason], "png text markers"
  end

  test "camera EXIF present without AI markers reduces score to zero with no ai signals reason" do
    exif_camera = "Make:Nikon\nModel:D750\nDateTimeOriginal:2020:01:01 00:00:00\nExposureTime:1/125\nFNumber:8\nISO:100"
    stub_vips_image(values: {
      "exif-data" => exif_camera,
      "exif-ifd0-Software" => "",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "",
      "xmp-data" => "",
      "jpeg-comment" => "",
      "jpeg-com" => "",
    })

    result = is_ai_generated?("/tmp/photo.jpg")
    assert_equal 0, result[:score]
    assert_equal "no ai signals", result[:reason]
  end

  test "scores are clamped to 100 and reasons aggregated" do
    stub_vips_image(values: {
      "exif-data" => "",
      "exif-ifd0-Software" => "",
      "exif-ifd0-ImageDescription" => "",
      "exif-ifd2-UserComment" => "Negative prompt: blurry",
      "xmp-data" => "Contains c2pa.org manifestStore",
      "jpeg-comment" => "",
      "jpeg-com" => "",
    })

    result = is_ai_generated?("/tmp/mixed.jpeg")
    assert_equal 100, result[:score]
    assert_includes result[:reason], "c2pa manifest present"
    assert_includes result[:reason], "ai parameter tokens found"
  end

  test "handles missing metadata fields gracefully" do
    # Simulate get_fields raising and all get() missing
    stub_vips_image(values: {}, fields: [], raise_on_get_fields: true)

    result = is_ai_generated?("/tmp/empty.jpg")
    assert_equal 0, result[:score]
    assert_equal "no ai signals", result[:reason]
  end

  test "fixture tokens.png flags SD parameter tokens" do
    path = file_fixture("ai/tokens.png").to_s
    result = is_ai_generated?(path)
    assert_operator result[:score], :>=, 60
    assert_includes result[:reason], "ai parameter tokens found"
  end

  test "fixture generator.png flags known generator" do
    path = file_fixture("ai/generator.png").to_s
    result = is_ai_generated?(path)
    # It should at least identify a known generator; score may be >= 70
    assert_match(/ai generator:\s*.+/i, result[:reason])
    assert_operator result[:score], :>=, 70
  end

  test "fixture bread-static.png is not AI generated" do
    path = file_fixture("bread-static.png").to_s
    result = is_ai_generated?(path)
    assert_equal 0, result[:score]
    assert_equal "no ai signals", result[:reason]
  end
end
