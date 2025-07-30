# frozen_string_literal: true

module SourceTestHelper
  def alternate_should_work(
    url,
    alternate_class,
    replacement_url
  )
    site = Sources::Alternates.find(url)

    should "be handled by the correct strategy" do
      assert(site.is_a?(alternate_class))
    end

    should "result in the correct URL" do
      assert_equal(replacement_url, site.original_url)
    end
  end
end
