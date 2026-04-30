# frozen_string_literal: true

require "test_helper"

module Sources
  class NullTest < ActiveSupport::TestCase
    context "A source from an unknown site" do
      setup do
        @site = Sources::Strategies.find("http://oremuhax.x0.com/yoro1603.jpg")
      end

      should "be handled by the null strategy" do
        assert(@site.is_a?(Sources::Strategies::Null))
      end

      should "find the metadata" do
        assert_equal(["http://oremuhax.x0.com/yoro1603.jpg"], @site.image_urls)
        assert_equal("http://oremuhax.x0.com/yoro1603.jpg", @site.image_url)
        assert_equal("http://oremuhax.x0.com/yoro1603.jpg", @site.canonical_url)
      end
    end
  end
end
