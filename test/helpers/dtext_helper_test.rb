# frozen_string_literal: true

require "test_helper"

class DtextHelperTest < ActionView::TestCase
  context "The DText helper" do
    context "format_text method" do
      should "not raise an exception for invalid DText" do
        dtext = "a\x00b"

        assert_nothing_raised { format_text(dtext) }
        assert_equal('<div class="styled-dtext"></div>', format_text(dtext))
      end
    end
  end
end
