# frozen_string_literal: true

require "test_helper"

class FileMethodsTest < ActiveSupport::TestCase
  class Dummy
    include FileMethods

    attr_accessor :file_ext

    def initialize(file_ext)
      @file_ext = file_ext
    end
  end

  def subject_for(ext)
    Dummy.new(ext)
  end

  context "is_animated_gif?" do
    should "return true for an animated gif" do
      path = file_fixture("bread-animated.gif")
      result = subject_for("gif").is_animated_gif_file?(path.to_s)
      assert_equal true, result
    end

    should "return false for a static gif" do
      path = file_fixture("bread-static.gif")
      result = subject_for("gif").is_animated_gif_file?(path.to_s)
      assert_equal false, result
    end
  end

  context "is_animated_png?" do
    should "return true for an animated apng" do
      path = file_fixture("apng/normal_apng.png")
      result = subject_for("png").is_animated_png_file?(path.to_s)
      assert_equal true, result
    end

    should "return false for a non-animated png" do
      path = file_fixture("apng/not_apng.png")
      result = subject_for("png").is_animated_png_file?(path.to_s)
      assert_equal false, result
    end
  end
end
