# frozen_string_literal: true

require "test_helper"

class TextHelperTest < ActionView::TestCase
  should "not call diff" do
    Open3.expects(:capture3).never
    text_diff("abc", "def")
  end

  should "strip the header info" do
    expected = <<~HTML.chomp
      <div class="diff">
        <ul>
          <li class="del"><del><strong>abc</strong></del></li>
          <li class="ins"><ins><strong>def</strong></ins></li>
        </ul>
      </div>

    HTML
    actual = text_diff("abc", "def")
    assert_equal(expected, actual)
  end

  should "escape html entities" do
    expected = <<~HTML.chomp
      <div class="diff">
        <ul>
          <li class="del"><del>&lt;<strong>s&gt;&lt;/s</strong>&gt;</del></li>
          <li class="ins"><ins>&lt;<strong>b&gt;&lt;/b</strong>&gt;</ins></li>
        </ul>
      </div>

    HTML
    actual = text_diff("<s></s>", "<b></b>")
    assert_equal(expected, actual)
  end
end
